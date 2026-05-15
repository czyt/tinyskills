package main

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	instanceRuntimeRoot    = "/tmp/lightos-zellij-webshell"
	zellijSessionName      = "lightos-zellij"
	zellijWebPort          = 39082
	zellijSessionMaxAgeSec = 28 * 24 * 60 * 60
)

//go:embed config.kdl.tpl
var zellijConfigTemplate string

type pluginServer struct {
	ctx      context.Context
	rootDir  string
	mu       sync.Mutex
	runtimes map[string]*instanceRuntime
}

type instanceRuntime struct {
	mu            sync.Mutex
	selector      string
	localPort     int
	forwardMu     sync.Mutex
	forwardCmd    *exec.Cmd
	forwardDone   chan error
	forwardErr    error
	forwardExited bool
	forwardLog    *bytes.Buffer
	prepared      bool
	zellijBinary  string
	configPath    string
	sessionMu     sync.Mutex
	sessions      map[string][]*http.Cookie
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	server := &pluginServer{
		ctx:      ctx,
		rootDir:  resolvePluginRoot(),
		runtimes: make(map[string]*instanceRuntime),
	}
	defer server.close()

	if err := server.run(ctx); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

func resolvePluginRoot() string {
	exe, err := os.Executable()
	if err != nil {
		return "."
	}
	return filepath.Dir(exe)
}

func (s *pluginServer) run(ctx context.Context) error {
	listener, err := net.Listen("tcp", "127.0.0.1:8080")
	if err != nil {
		return err
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/", s.handleRoot)
	mux.HandleFunc("/proxy/", s.handleProxy)

	httpServer := &http.Server{
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}
	errCh := make(chan error, 1)
	go func() {
		errCh <- httpServer.Serve(listener)
	}()
	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = httpServer.Shutdown(shutdownCtx)
		return nil
	case err := <-errCh:
		return err
	}
}

func (s *pluginServer) close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, runtime := range s.runtimes {
		if runtime != nil && runtime.forwardCmd != nil && runtime.forwardCmd.Process != nil {
			_ = runtime.forwardCmd.Process.Kill()
		}
	}
}

func (s *pluginServer) handleHealthz(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func (s *pluginServer) handleRoot(w http.ResponseWriter, r *http.Request) {
	switch strings.TrimSpace(r.URL.Path) {
	case "", "/":
	default:
		http.NotFound(w, r)
		return
	}
	selector := strings.TrimSpace(r.URL.Query().Get("name"))
	if selector == "" {
		http.Error(w, "missing instance selector: name=<name>@<owner_deploy_id>", http.StatusBadRequest)
		return
	}
	runtime, err := s.ensureInstanceRuntime(selector)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	http.Redirect(w, r, runtime.proxyPath("/"+zellijSessionName), http.StatusFound)
}

func (s *pluginServer) handleProxy(w http.ResponseWriter, r *http.Request) {
	selector, targetPath, ok := parseProxyPath(r.URL.Path)
	if !ok {
		http.NotFound(w, r)
		return
	}
	runtime, err := s.ensureInstanceRuntime(selector)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	switch targetPath {
	case "/command/login":
		s.handleProxyLogin(runtime, w, r)
	case "/session":
		s.handleProxySession(runtime, w, r)
	default:
		s.newZellijProxy(runtime).ServeHTTP(w, r)
	}
}

func parseProxyPath(pathValue string) (string, string, bool) {
	rest := strings.TrimPrefix(pathValue, "/proxy/")
	if rest == pathValue || rest == "" {
		return "", "", false
	}
	encodedSelector, target, _ := strings.Cut(rest, "/")
	selector, err := url.PathUnescape(encodedSelector)
	if err != nil || strings.TrimSpace(selector) == "" {
		return "", "", false
	}
	targetPath := "/" + target
	if target == "" {
		targetPath = "/"
	}
	return selector, targetPath, true
}

func (r *instanceRuntime) proxyBasePath() string {
	return "/proxy/" + url.PathEscape(r.selector)
}

func (r *instanceRuntime) proxyPath(targetPath string) string {
	cleanTarget := "/" + strings.TrimLeft(strings.TrimSpace(targetPath), "/")
	return r.proxyBasePath() + cleanTarget
}

func (s *pluginServer) ensureInstanceRuntime(selector string) (*instanceRuntime, error) {
	selector = strings.TrimSpace(selector)
	if selector == "" {
		return nil, errors.New("instance selector is required")
	}

	s.mu.Lock()
	runtime := s.runtimes[selector]
	if runtime == nil {
		runtime = &instanceRuntime{
			selector:     selector,
			zellijBinary: instanceRuntimeRoot + "/bin/zellij",
			configPath:   instanceRuntimeRoot + "/config/lightos-web.kdl",
			sessions:     make(map[string][]*http.Cookie),
		}
		s.runtimes[selector] = runtime
	}
	s.mu.Unlock()

	runtime.mu.Lock()
	defer runtime.mu.Unlock()
	ctx, cancel := s.prepareContext()
	defer cancel()
	if runtime.prepared {
		prepared, err := s.instanceRuntimePrepared(ctx, runtime)
		if err != nil {
			return nil, err
		}
		if !prepared {
			runtime.prepared = false
			runtime.stopForward()
		}
	}
	if !runtime.prepared {
		if err := s.prepareInstanceRuntime(ctx, runtime); err != nil {
			return nil, err
		}
		runtime.prepared = true
	}
	if err := s.ensureForward(ctx, runtime); err != nil {
		return nil, err
	}
	return runtime, nil
}

func (s *pluginServer) prepareContext() (context.Context, context.CancelFunc) {
	parent := s.ctx
	if parent == nil {
		parent = context.Background()
	}
	return context.WithTimeout(parent, 2*time.Minute)
}

func (s *pluginServer) prepareInstanceRuntime(ctx context.Context, runtime *instanceRuntime) error {
	localZellij := filepath.Join(s.rootDir, "zellij")
	if _, err := os.Stat(localZellij); err != nil {
		return fmt.Errorf("zellij binary is missing: %w", err)
	}
	if err := s.writeInstanceFile(ctx, runtime.selector, localZellij, runtime.zellijBinary, "0755"); err != nil {
		return fmt.Errorf("install zellij in instance: %w", err)
	}
	configContent := buildZellijConfig("/bin/sh", instanceRuntimeRoot+"/home", runtime.proxyBasePath()+"/")
	if err := s.writeInstanceText(ctx, runtime.selector, configContent, runtime.configPath, "0644"); err != nil {
		return fmt.Errorf("write zellij config in instance: %w", err)
	}
	if err := s.runInstanceShell(ctx, runtime.selector, buildInstanceBootstrapScript(runtime)); err != nil {
		return fmt.Errorf("prepare zellij web in instance: %w", err)
	}
	return nil
}

func (s *pluginServer) instanceRuntimePrepared(ctx context.Context, runtime *instanceRuntime) (bool, error) {
	script := strings.Join([]string{
		"set -eu",
		"test -x " + shellQuote(runtime.zellijBinary),
		"test -f " + shellQuote(runtime.configPath),
		"export HOME=" + shellQuote(instanceRuntimeRoot+"/home"),
		"export ZELLIJ_SOCKET_DIR=" + shellQuote(instanceRuntimeRoot+"/socket"),
		shellQuote(runtime.zellijBinary) + " --config " + shellQuote(runtime.configPath) + " web --status --port " + strconv.Itoa(zellijWebPort) + " --timeout 5",
	}, "\n")
	output, err := s.runLightOSCtl(ctx, nil, "exec", runtime.selector, "/bin/sh", "-lc", script)
	if err == nil && zellijWebStatusOnline(output) {
		return true, nil
	}
	text := strings.TrimSpace(string(output))
	if text != "" {
		log.Printf("zellij runtime check failed for %s: %v: %s", runtime.selector, err, text)
	} else {
		log.Printf("zellij runtime check failed for %s: %v", runtime.selector, err)
	}
	return false, nil
}

func zellijWebStatusOnline(output []byte) bool {
	status := strings.ToLower(strings.TrimSpace(string(output)))
	return strings.Contains(status, "web server online")
}

func (s *pluginServer) ensureForward(ctx context.Context, runtime *instanceRuntime) error {
	if runtime.forwardCmd != nil && !forwardExited(runtime) && localPortListening(runtime.localPort) {
		return nil
	}
	runtime.stopForward()
	port, err := reserveLocalPort()
	if err != nil {
		return err
	}
	spec := fmt.Sprintf("127.0.0.1:%d:127.0.0.1:%d", port, zellijWebPort)
	cmd := exec.Command(s.lightosctlPath(), "forward", "-L", spec, runtime.selector)
	forwardLog := &bytes.Buffer{}
	cmd.Stdout = forwardLog
	cmd.Stderr = forwardLog
	if err := cmd.Start(); err != nil {
		return err
	}
	runtime.localPort = port
	done := make(chan error, 1)
	runtime.forwardCmd = cmd
	runtime.forwardDone = done
	runtime.forwardErr = nil
	runtime.forwardExited = false
	runtime.forwardLog = forwardLog
	go func() {
		err := cmd.Wait()
		runtime.forwardMu.Lock()
		if runtime.forwardCmd == cmd {
			runtime.forwardErr = err
			runtime.forwardExited = true
		}
		runtime.forwardMu.Unlock()
		done <- err
	}()
	if err := waitForwardReady(ctx, runtime); err != nil {
		runtime.stopForward()
		return err
	}
	return nil
}

func (r *instanceRuntime) stopForward() {
	r.forwardMu.Lock()
	defer r.forwardMu.Unlock()
	if r.forwardCmd != nil && r.forwardCmd.Process != nil {
		_ = r.forwardCmd.Process.Kill()
	}
	r.localPort = 0
	r.forwardCmd = nil
	r.forwardDone = nil
	r.forwardErr = nil
	r.forwardExited = false
	r.forwardLog = nil
}

func (s *pluginServer) lightosctlPath() string {
	return "/lzcinit/lightosctl"
}

func forwardExited(runtime *instanceRuntime) bool {
	runtime.forwardMu.Lock()
	defer runtime.forwardMu.Unlock()
	return runtime.forwardExited
}

func reserveLocalPort() (int, error) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer func() {
		_ = listener.Close()
	}()
	addr, ok := listener.Addr().(*net.TCPAddr)
	if !ok {
		return 0, errors.New("failed to reserve local tcp port")
	}
	return addr.Port, nil
}

func waitForwardReady(ctx context.Context, runtime *instanceRuntime) error {
	deadline := time.Now().Add(5 * time.Second)
	addr := "127.0.0.1:" + strconv.Itoa(runtime.localPort)
	for {
		if localPortListening(runtime.localPort) {
			return nil
		}
		select {
		case forwardErr := <-runtime.forwardDone:
			output := ""
			if runtime.forwardLog != nil {
				output = strings.TrimSpace(runtime.forwardLog.String())
			}
			if output != "" {
				return fmt.Errorf("lightosctl forward exited: %w: %s", forwardErr, output)
			}
			return fmt.Errorf("lightosctl forward exited: %w", forwardErr)
		default:
		}
		if time.Now().After(deadline) {
			output := ""
			if runtime.forwardLog != nil {
				output = strings.TrimSpace(runtime.forwardLog.String())
			}
			if output != "" {
				return fmt.Errorf("lightosctl forward did not listen on %s: %s", addr, output)
			}
			return fmt.Errorf("lightosctl forward did not listen on %s", addr)
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(100 * time.Millisecond):
		}
	}
}

func localPortListening(port int) bool {
	if port <= 0 {
		return false
	}
	data, err := os.ReadFile("/proc/net/tcp")
	if err != nil {
		return false
	}
	target := fmt.Sprintf("0100007F:%04X", port)
	for _, line := range strings.Split(string(data), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 4 {
			continue
		}
		if strings.EqualFold(fields[1], target) && fields[3] == "0A" {
			return true
		}
	}
	return false
}

func buildInstanceBootstrapScript(runtime *instanceRuntime) string {
	return strings.Join([]string{
		"set -eu",
		"export HOME=" + shellQuote(instanceRuntimeRoot+"/home"),
		"export ZELLIJ_SOCKET_DIR=" + shellQuote(instanceRuntimeRoot+"/socket"),
		"mkdir -p \"$HOME\" \"$ZELLIJ_SOCKET_DIR\" " + shellQuote(filepath.Dir(runtime.configPath)),
		"if [ -f /run/catlink/shell-env.sh ]; then . /run/catlink/shell-env.sh; fi",
		"if ! " + shellQuote(runtime.zellijBinary) + " list-sessions --short | grep -Fx " + shellQuote(zellijSessionName) + " >/dev/null 2>&1; then " + shellQuote(runtime.zellijBinary) + " --config " + shellQuote(runtime.configPath) + " attach --create-background " + shellQuote(zellijSessionName) + "; fi",
		"status=$(" + shellQuote(runtime.zellijBinary) + " --config " + shellQuote(runtime.configPath) + " web --status --port " + strconv.Itoa(zellijWebPort) + " --timeout 5 2>&1)",
		"case \"$status\" in *'Web server online'*) ;; *) if ! start_output=$(" + shellQuote(runtime.zellijBinary) + " --config " + shellQuote(runtime.configPath) + " web --start --daemonize --port " + strconv.Itoa(zellijWebPort) + " 2>&1); then status_after=$(" + shellQuote(runtime.zellijBinary) + " --config " + shellQuote(runtime.configPath) + " web --status --port " + strconv.Itoa(zellijWebPort) + " --timeout 5 2>&1); case \"$status_after\" in *'Web server online'*) ;; *) printf '%s\\n%s\\n' \"$start_output\" \"$status_after\" >&2; exit 1 ;; esac; fi ;; esac",
		"status=$(" + shellQuote(runtime.zellijBinary) + " --config " + shellQuote(runtime.configPath) + " web --status --port " + strconv.Itoa(zellijWebPort) + " --timeout 5 2>&1)",
		"case \"$status\" in *'Web server online'*) ;; *) printf '%s\\n' \"$status\" >&2; exit 1 ;; esac",
	}, "\n")
}

func buildZellijConfig(defaultShellValue, defaultCwd, baseURL string) string {
	normalizedBaseURL := strings.TrimSpace(baseURL)
	if normalizedBaseURL == "" {
		normalizedBaseURL = "/proxy/"
	}
	if !strings.HasSuffix(normalizedBaseURL, "/") {
		normalizedBaseURL += "/"
	}
	replacer := strings.NewReplacer(
		"__DEFAULT_SHELL__", strconv.Quote(strings.TrimSpace(defaultShellValue)),
		"__DEFAULT_CWD__", strconv.Quote(strings.TrimSpace(defaultCwd)),
		"__BASE_URL__", strconv.Quote(normalizedBaseURL),
		"__WEB_SERVER_PORT__", strconv.Itoa(zellijWebPort),
	)
	return replacer.Replace(zellijConfigTemplate)
}

func (s *pluginServer) runInstanceShell(ctx context.Context, selector string, script string) error {
	output, err := s.runLightOSCtl(ctx, nil, "exec", selector, "/bin/sh", "-lc", script)
	if err != nil {
		text := strings.TrimSpace(string(output))
		if text == "" {
			return err
		}
		return fmt.Errorf("%w: %s", err, text)
	}
	return nil
}

func (s *pluginServer) writeInstanceFile(ctx context.Context, selector string, localPath string, remotePath string, mode string) error {
	file, err := os.Open(localPath)
	if err != nil {
		return err
	}
	defer func() {
		_ = file.Close()
	}()
	return s.writeInstanceReader(ctx, selector, file, remotePath, mode)
}

func (s *pluginServer) writeInstanceText(ctx context.Context, selector string, content string, remotePath string, mode string) error {
	return s.writeInstanceReader(ctx, selector, strings.NewReader(content), remotePath, mode)
}

func (s *pluginServer) writeInstanceReader(ctx context.Context, selector string, reader io.Reader, remotePath string, mode string) error {
	script := "set -eu; mkdir -p " + shellQuote(filepath.Dir(remotePath)) + "; cat > " + shellQuote(remotePath) + "; chmod " + shellQuote(mode) + " " + shellQuote(remotePath)
	output, err := s.runLightOSCtl(ctx, reader, "exec", "-i", selector, "/bin/sh", "-lc", script)
	if err != nil {
		text := strings.TrimSpace(string(output))
		if text == "" {
			return err
		}
		return fmt.Errorf("%w: %s", err, text)
	}
	return nil
}

func (s *pluginServer) runLightOSCtl(ctx context.Context, stdin io.Reader, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, s.lightosctlPath(), args...)
	if stdin != nil {
		cmd.Stdin = stdin
	}
	return cmd.CombinedOutput()
}

func (s *pluginServer) createLoginToken(ctx context.Context, runtime *instanceRuntime) (string, string, error) {
	script := strings.Join([]string{
		"set -eu",
		"export HOME=" + shellQuote(instanceRuntimeRoot+"/home"),
		"export ZELLIJ_SOCKET_DIR=" + shellQuote(instanceRuntimeRoot+"/socket"),
		shellQuote(runtime.zellijBinary) + " --config " + shellQuote(runtime.configPath) + " web --create-token",
	}, "\n")
	output, err := s.runLightOSCtl(ctx, nil, "exec", runtime.selector, "/bin/sh", "-lc", script)
	if err != nil {
		text := strings.TrimSpace(string(output))
		if text == "" {
			return "", "", err
		}
		return "", "", fmt.Errorf("%w: %s", err, text)
	}
	for _, rawLine := range strings.Split(string(output), "\n") {
		line := strings.TrimSpace(rawLine)
		if line == "" || !strings.Contains(line, ":") {
			continue
		}
		name, token, ok := strings.Cut(line, ":")
		if !ok {
			continue
		}
		name = strings.TrimSpace(name)
		token = strings.TrimSpace(token)
		if name != "" && token != "" {
			return name, token, nil
		}
	}
	return "", "", errors.New("failed to parse created zellij token")
}

func (s *pluginServer) newZellijProxy(runtime *instanceRuntime) *httputil.ReverseProxy {
	target := &url.URL{Scheme: "http", Host: "127.0.0.1:" + strconv.Itoa(runtime.localPort)}
	proxy := httputil.NewSingleHostReverseProxy(target)
	proxy.Transport = &http.Transport{
		DisableKeepAlives: true,
		ForceAttemptHTTP2: false,
		Proxy:             nil,
	}
	proxy.ErrorHandler = func(rw http.ResponseWriter, req *http.Request, proxyErr error) {
		http.Error(rw, runtime.proxyError(proxyErr), http.StatusBadGateway)
	}
	proxy.ModifyResponse = func(resp *http.Response) error {
		targetPath := "/"
		if resp != nil && resp.Request != nil && resp.Request.URL != nil {
			targetPath = resp.Request.URL.Path
		}
		return rewriteZellijProxyResponse(resp, targetPath, runtime.proxyBasePath())
	}
	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		originalDirector(req)
		_, targetPath, ok := parseProxyPath(req.URL.Path)
		if !ok {
			targetPath = "/"
		}
		req.URL.Path = targetPath
		req.URL.RawPath = ""
		req.Host = target.Host
		runtime.injectSessionCookies(req, targetPath)
	}
	return proxy
}

func rewriteZellijProxyResponse(resp *http.Response, targetPath string, basePath string) error {
	if resp == nil || resp.Body == nil {
		return nil
	}
	switch strings.TrimSpace(targetPath) {
	case "/assets/auth.js":
		return rewriteZellijAuthJS(resp)
	case "/assets/websockets.js":
		return rewriteZellijWebsocketsJS(resp)
	default:
		return rewriteZellijHTMLBaseHref(resp, basePath)
	}
}

func (r *instanceRuntime) proxyError(proxyErr error) string {
	parts := []string{proxyErr.Error()}
	r.forwardMu.Lock()
	forwardDone := r.forwardDone != nil
	forwardExited := r.forwardExited
	forwardErr := r.forwardErr
	forwardOutput := ""
	if r.forwardLog != nil {
		forwardOutput = strings.TrimSpace(r.forwardLog.String())
	}
	r.forwardMu.Unlock()
	if forwardDone {
		if forwardExited {
			parts = append(parts, "forward exited: "+stringError(forwardErr))
		} else {
			parts = append(parts, "forward running")
		}
	}
	if forwardOutput != "" {
		parts = append(parts, "forward output: "+forwardOutput)
	}
	return strings.Join(parts, "\n")
}

func stringError(err error) string {
	if err == nil {
		return "<nil>"
	}
	return err.Error()
}

func rewriteZellijHTMLBaseHref(resp *http.Response, basePath string) error {
	contentType := strings.ToLower(strings.TrimSpace(resp.Header.Get("Content-Type")))
	if !strings.Contains(contentType, "text/html") {
		return nil
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	_ = resp.Body.Close()
	normalizedBasePath := strings.TrimSpace(basePath)
	if normalizedBasePath != "" && !strings.HasSuffix(normalizedBasePath, "/") {
		normalizedBasePath += "/"
	}
	rewritten := strings.Replace(string(body), `<base href="/proxy/" />`, `<base href="`+normalizedBasePath+`" />`, 1)
	body = []byte(rewritten)
	resp.Body = io.NopCloser(bytes.NewReader(body))
	resp.ContentLength = int64(len(body))
	resp.Header.Set("Content-Length", strconv.Itoa(len(body)))
	return nil
}

const zellijAutoLoginModulePatch = `
async function getSecurityToken() {
	return { token: "__LIGHTOS_AUTO_LOGIN__", remember: true };
}
`

func rewriteZellijAuthJS(resp *http.Response) error {
	contentType := strings.ToLower(strings.TrimSpace(resp.Header.Get("Content-Type")))
	if !strings.Contains(contentType, "javascript") && !strings.Contains(contentType, "ecmascript") {
		return nil
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	_ = resp.Body.Close()
	rewritten := strings.Replace(
		string(body),
		`import { getBaseUrl } from "./utils.js";`,
		`import { getBaseUrl } from "./utils.js";`+zellijAutoLoginModulePatch,
		1,
	)
	body = []byte(rewritten)
	resp.Body = io.NopCloser(bytes.NewReader(body))
	resp.ContentLength = int64(len(body))
	resp.Header.Set("Content-Length", strconv.Itoa(len(body)))
	return nil
}

func rewriteZellijWebsocketsJS(resp *http.Response) error {
	contentType := strings.ToLower(strings.TrimSpace(resp.Header.Get("Content-Type")))
	if !strings.Contains(contentType, "javascript") && !strings.Contains(contentType, "ecmascript") {
		return nil
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	_ = resp.Body.Close()
	rewritten := strings.Replace(
		string(body),
		"const wsControlUrl = `${wsBaseUrl}/ws/control`;",
		"const wsControlUrl = `${wsBaseUrl}/ws/control${queryString}`;",
		1,
	)
	body = []byte(rewritten)
	resp.Body = io.NopCloser(bytes.NewReader(body))
	resp.ContentLength = int64(len(body))
	resp.Header.Set("Content-Length", strconv.Itoa(len(body)))
	return nil
}

func (s *pluginServer) handleProxyLogin(runtime *instanceRuntime, w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	_, token, err := s.createLoginToken(r.Context(), runtime)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	body, header, loginCookies, statusCode, err := s.loginZellij(r.Context(), runtime, token, r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	for _, sessionCookie := range rewriteZellijLoginCookies(loginCookies, runtime.proxyBasePath(), r.TLS != nil) {
		http.SetCookie(w, sessionCookie)
	}
	if contentType := strings.TrimSpace(header.Get("Content-Type")); contentType != "" {
		w.Header().Set("Content-Type", contentType)
	}
	w.WriteHeader(statusCode)
	_, _ = w.Write(body)
}

func (s *pluginServer) handleProxySession(runtime *instanceRuntime, w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	_, token, err := s.createLoginToken(r.Context(), runtime)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	_, _, loginCookies, statusCode, err := s.loginZellij(r.Context(), runtime, token, r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	if statusCode != http.StatusOK {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}
	for _, sessionCookie := range rewriteZellijLoginCookies(loginCookies, runtime.proxyBasePath(), r.TLS != nil) {
		http.SetCookie(w, sessionCookie)
	}
	body, header, sessionStatus, err := s.openZellijSession(r.Context(), runtime, loginCookies, r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	if sessionStatus == http.StatusOK {
		if webClientID := parseWebClientID(body); webClientID != "" {
			runtime.storeSessionCookies(webClientID, loginCookies)
		}
	}
	if contentType := strings.TrimSpace(header.Get("Content-Type")); contentType != "" {
		w.Header().Set("Content-Type", contentType)
	}
	w.WriteHeader(sessionStatus)
	_, _ = w.Write(body)
}

func (s *pluginServer) loginZellij(ctx context.Context, runtime *instanceRuntime, authToken string, browserRequest *http.Request) ([]byte, http.Header, []*http.Cookie, int, error) {
	payload, err := json.Marshal(map[string]any{
		"auth_token":  strings.TrimSpace(authToken),
		"remember_me": true,
	})
	if err != nil {
		return nil, nil, nil, 0, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "http://127.0.0.1:"+strconv.Itoa(runtime.localPort)+"/command/login", bytes.NewReader(payload))
	if err != nil {
		return nil, nil, nil, 0, err
	}
	if browserRequest != nil {
		req.Header = browserRequest.Header.Clone()
		req.Header.Del("Cookie")
		req.Header.Del("Content-Length")
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := (&http.Client{Transport: &http.Transport{DisableKeepAlives: true, ForceAttemptHTTP2: false}}).Do(req)
	if err != nil {
		return nil, nil, nil, 0, err
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, nil, nil, 0, err
	}
	return body, resp.Header.Clone(), resp.Cookies(), resp.StatusCode, nil
}

func (s *pluginServer) openZellijSession(ctx context.Context, runtime *instanceRuntime, authCookies []*http.Cookie, browserRequest *http.Request) ([]byte, http.Header, int, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "http://127.0.0.1:"+strconv.Itoa(runtime.localPort)+"/session", bytes.NewReader([]byte(`{}`)))
	if err != nil {
		return nil, nil, 0, err
	}
	if browserRequest != nil {
		req.Header = browserRequest.Header.Clone()
		req.Header.Del("Cookie")
		req.Header.Del("Content-Length")
	}
	req.Header.Set("Content-Type", "application/json")
	for _, cookie := range authCookies {
		if cookie == nil || strings.TrimSpace(cookie.Name) == "" || strings.TrimSpace(cookie.Value) == "" {
			continue
		}
		req.AddCookie(cookie)
	}
	resp, err := (&http.Client{Transport: &http.Transport{DisableKeepAlives: true, ForceAttemptHTTP2: false}}).Do(req)
	if err != nil {
		return nil, nil, 0, err
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, nil, 0, err
	}
	return body, resp.Header.Clone(), resp.StatusCode, nil
}

func parseWebClientID(body []byte) string {
	var payload struct {
		WebClientID string `json:"web_client_id"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		return ""
	}
	return strings.TrimSpace(payload.WebClientID)
}

func (r *instanceRuntime) storeSessionCookies(webClientID string, cookies []*http.Cookie) {
	webClientID = strings.TrimSpace(webClientID)
	if webClientID == "" || len(cookies) == 0 {
		return
	}
	stored := make([]*http.Cookie, 0, len(cookies))
	for _, cookie := range cookies {
		if cookie == nil || strings.TrimSpace(cookie.Name) == "" || strings.TrimSpace(cookie.Value) == "" {
			continue
		}
		copyCookie := *cookie
		copyCookie.Path = ""
		copyCookie.Domain = ""
		stored = append(stored, &copyCookie)
	}
	if len(stored) == 0 {
		return
	}
	r.sessionMu.Lock()
	defer r.sessionMu.Unlock()
	r.sessions[webClientID] = stored
}

func (r *instanceRuntime) injectSessionCookies(req *http.Request, targetPath string) {
	if req == nil || !strings.HasPrefix(strings.TrimSpace(targetPath), "/ws/") {
		return
	}
	webClientID := strings.TrimSpace(req.URL.Query().Get("web_client_id"))
	if webClientID == "" {
		return
	}
	r.sessionMu.Lock()
	cookies := cloneCookies(r.sessions[webClientID])
	r.sessionMu.Unlock()
	if len(cookies) == 0 {
		return
	}
	replaceRequestCookies(req, cookies)
}

func cloneCookies(cookies []*http.Cookie) []*http.Cookie {
	cloned := make([]*http.Cookie, 0, len(cookies))
	for _, cookie := range cookies {
		if cookie == nil {
			continue
		}
		copyCookie := *cookie
		cloned = append(cloned, &copyCookie)
	}
	return cloned
}

func replaceRequestCookies(req *http.Request, upstreamCookies []*http.Cookie) {
	if req == nil || len(upstreamCookies) == 0 {
		return
	}
	replaceNames := make(map[string]struct{}, len(upstreamCookies))
	for _, cookie := range upstreamCookies {
		if cookie == nil || strings.TrimSpace(cookie.Name) == "" {
			continue
		}
		replaceNames[cookie.Name] = struct{}{}
	}
	nextCookies := make([]*http.Cookie, 0, len(req.Cookies())+len(upstreamCookies))
	for _, cookie := range req.Cookies() {
		if cookie == nil {
			continue
		}
		if _, replace := replaceNames[cookie.Name]; replace {
			continue
		}
		nextCookies = append(nextCookies, cookie)
	}
	nextCookies = append(nextCookies, upstreamCookies...)
	if len(nextCookies) == 0 {
		req.Header.Del("Cookie")
		return
	}
	var builder strings.Builder
	for index, cookie := range nextCookies {
		if cookie == nil || strings.TrimSpace(cookie.Name) == "" {
			continue
		}
		if index > 0 && builder.Len() > 0 {
			builder.WriteString("; ")
		}
		builder.WriteString(cookie.Name)
		builder.WriteString("=")
		builder.WriteString(cookie.Value)
	}
	req.Header.Set("Cookie", builder.String())
}

func rewriteZellijLoginCookies(upstreamCookies []*http.Cookie, basePath string, secure bool) []*http.Cookie {
	sessionCookies := make([]*http.Cookie, 0, len(upstreamCookies))
	normalizedBasePath := strings.TrimSpace(basePath)
	if normalizedBasePath == "" {
		normalizedBasePath = "/proxy"
	}
	for _, upstreamCookie := range upstreamCookies {
		if strings.TrimSpace(upstreamCookie.Name) == "" || strings.TrimSpace(upstreamCookie.Value) == "" {
			continue
		}
		sessionCookies = append(sessionCookies, &http.Cookie{
			Name:     upstreamCookie.Name,
			Value:    upstreamCookie.Value,
			Path:     normalizedBasePath,
			HttpOnly: true,
			Secure:   upstreamCookie.Secure || secure,
			SameSite: http.SameSiteStrictMode,
			MaxAge:   zellijSessionMaxAgeSec,
		})
	}
	return sessionCookies
}

func shellQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "'\"'\"'") + "'"
}
