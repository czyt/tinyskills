# LazyCat MCP / Skill 资源集成

本页覆盖三类工作：
1. Agent 类应用发现微服里的 Skill 和 MCP provider。
2. 网关类应用动态聚合多个 MCP provider 的 tools。
3. 普通应用对外提供 `/mcp` 并让 LazyCat 资源系统发现。

要求：`lzcos >= 1.5.2`。

---

## 1. 发现系统 Skill / MCP

### Package 配置

读取系统资源的应用必须声明 `import_resources`：

```yaml
# package.yml
min_os_version: 1.5.2
permissions:
  required:
    - lzcapp.user_delegate # 访问其他应用 MCP 时需要

import_resources:
  - kind: skills
  - kind: mcp-providers
```

运行时资源根目录：

```text
/lzcapp/run/resources/
  skills/
    <app-id>/
      <skill-id>/SKILL.md
  mcp-providers/
    <app-id>/
      <provider-id>/mcp.yml
```

`mcp.yml` 最小格式：

```yaml
endpoint: /mcp
```

完整 MCP URL：

```text
http://app.<app-id>.lzcx<endpoint>
```

如果 endpoint 是 `/mcp?view=default`，完整 URL 是：

```text
http://app.cloud.lazycat.app.todo.lzcx/mcp?view=default
```

### Go 扫描器骨架

```go
type MCPResource struct {
    AppID      string
    ResourceID string
    Endpoint   string
    FilePath   string
}

type SkillResource struct {
    AppID      string
    ResourceID string
    FilePath   string
    PublicPath string
}

func ScanMCPProviders(root string) ([]MCPResource, error) {
    base := filepath.Join(root, "mcp-providers")
    appDirs, err := os.ReadDir(base)
    if err != nil {
        return nil, nil // import_resources may be absent; treat as empty
    }

    var out []MCPResource
    for _, appDir := range appDirs {
        if !appDir.IsDir() || strings.HasPrefix(appDir.Name(), ".") {
            continue
        }
        providerRoot := filepath.Join(base, appDir.Name())
        providerDirs, _ := os.ReadDir(providerRoot)
        for _, providerDir := range providerDirs {
            if !providerDir.IsDir() || strings.HasPrefix(providerDir.Name(), ".") {
                continue
            }
            filePath := filepath.Join(providerRoot, providerDir.Name(), "mcp.yml")
            endpoint, err := readEndpoint(filePath)
            if err != nil {
                continue
            }
            out = append(out, MCPResource{
                AppID: appDir.Name(), ResourceID: providerDir.Name(),
                Endpoint: endpoint, FilePath: filePath,
            })
        }
    }
    return out, nil
}

func readEndpoint(filePath string) (string, error) {
    var doc struct{ Endpoint string `yaml:"endpoint"` }
    data, err := os.ReadFile(filePath)
    if err != nil {
        return "", err
    }
    if err := yaml.Unmarshal(data, &doc); err != nil {
        return "", err
    }
    endpoint := strings.TrimSpace(doc.Endpoint)
    if endpoint == "" || !strings.HasPrefix(endpoint, "/") {
        return "", fmt.Errorf("invalid endpoint")
    }
    return endpoint, nil
}
```

Skill 扫描规则：

```text
/lzcapp/run/resources/skills/<app-id>/SKILL.md
/lzcapp/run/resources/skills/<app-id>/<skill-id>/SKILL.md
```

服务自己的 Skill 文件可通过只读 HTTP 暴露：

```go
func serveSkill(w http.ResponseWriter, r *http.Request, root string) {
    rel := strings.TrimPrefix(r.URL.Path, "/skills/")
    if rel == "" || strings.Contains(rel, "..") || strings.HasPrefix(rel, "/") {
        http.NotFound(w, r)
        return
    }
    http.ServeFile(w, r, filepath.Join(root, "skills", rel))
}
```

---

## 2. `.lzcx` 与用户票据

访问其他应用 MCP provider：

```go
func LazyCatTargetURL(appID, endpoint string) (string, error) {
    parsed, err := url.Parse(endpoint)
    if err != nil {
        return "", err
    }
    if parsed.IsAbs() || parsed.Host != "" || !strings.HasPrefix(parsed.Path, "/") {
        return "", fmt.Errorf("provider endpoint must be an absolute path")
    }
    parsed.Scheme = "http"
    parsed.Host = "app." + appID + ".lzcx"
    return parsed.String(), nil
}
```

请求头：

```go
func HeadersForLazyCatUpstream(in http.Header, ticket string) http.Header {
    out := make(http.Header)
    for _, key := range []string{"Authorization", "Accept", "Content-Type"} {
        for _, value := range in.Values(key) {
            out.Add(key, value)
        }
    }
    out.Set("X-HC-USER-TICKET", ticket)
    return out
}
```

票据来源：
- `package.yml` 声明 `lzcapp.user_delegate`。
- 用户真实访问当前应用时，LazyCat 注入 `X-HC-USER-TICKET`。
- 后端把 ticket 保存到用户会话或短期内存；没有 ticket 时返回 `412 Precondition Required`，提示用户打开控制台刷新授权上下文。

不要主动伪造 `X-HC-USER-ID`。目标应用会从平台侧解析用户语义。

---

## 3. 动态 MCP 工具列表

网关类应用的核心流程：

1. 读取 `mcp-providers` 资源和用户配置的外部 provider。
2. 为每个启用 provider 创建 MCP client。
3. 对上游执行 `Initialize` 和 `ListTools`。
4. 将工具名改成 `<provider_slug>__<upstream_tool_name>`。
5. 把这些工具注册到本地 MCP server。
6. 调用聚合工具时，还原上游工具名并转发 `arguments`。

### 刷新逻辑

```go
func refreshUpstreamTools(ctx context.Context, providers []Provider, server ToolRegistry) {
    used := server.LocalToolNames()
    var add []ServerTool

    for _, provider := range providers {
        tools, err := listUpstreamTools(ctx, provider)
        if err != nil {
            log.Printf("provider %s tools/list failed: %v", provider.Slug, err)
            continue
        }
        for _, tool := range tools {
            upstreamName := tool.Name
            aggregateName := uniqueName(provider.Slug+"__"+upstreamName, used)
            tool.Name = aggregateName
            tool.Description = "Upstream MCP provider " + provider.Slug + " tool " + upstreamName + ". " + tool.Description
            ref := ToolRef{ProviderSlug: provider.Slug, UpstreamName: upstreamName}
            add = append(add, ServerTool{Tool: tool, Handler: proxyTool(ref)})
        }
    }

    server.ReplaceUpstreamTools(add)
}
```

### 上游调用

```go
func proxyTool(ref ToolRef) ToolHandler {
    return func(ctx context.Context, req CallToolRequest) (*CallToolResult, error) {
        provider := loadEnabledProvider(ref.ProviderSlug)
        client := newStreamableHTTPClient(provider.URL, provider.Headers)
        defer client.Close()

        if err := client.Start(ctx); err != nil {
            return ToolError(err), nil
        }
        if _, err := client.Initialize(ctx, initializeRequest()); err != nil {
            return ToolError(err), nil
        }
        return client.CallTool(ctx, CallToolRequest{
            Name:      ref.UpstreamName,
            Arguments: req.Arguments,
        })
    }
}
```

Failure policy:
- `ListTools` 失败只影响对应 provider，不删除本地工具。
- provider 成功刷新后，再替换该 provider 的旧工具。
- 不支持聚合的 transport（例如只支持 SSE 的 provider）保留代理端点，不加入聚合 tools。
- 工具名冲突必须用后缀或 slug 命名空间解决，不能覆盖。

---

## 4. 应用对外提供 MCP

### LazyCat 打包

Provider 应用自身导出 MCP：

```yaml
# lzc-build.yml
resource_exports:
  - kind: mcp-providers
    source: ./resources/mcp-providers
```

```text
resources/
  mcp-providers/
    <provider-id>/
      mcp.yml
```

```yaml
# resources/mcp-providers/<provider-id>/mcp.yml
endpoint: /mcp
```

如果同时提供 Skill：

```yaml
# lzc-build.yml
resource_exports:
  - kind: skills
    source: ./resources/skills
  - kind: mcp-providers
    source: ./resources/mcp-providers
```

```text
resources/skills/<skill-id>/SKILL.md
```

Provider 自身不需要 `lzcapp.user_delegate`。调用其他应用 MCP 的 consumer 或 gateway 才需要。

### Go MCP server 模式

推荐 Streamable HTTP：

```go
func NewMCPHandler(app *App) http.Handler {
    server := mcp.NewServer(&mcp.Implementation{
        Name: "my-app", Title: "My App", Version: Version,
    }, nil)

    mcp.AddTool(server, &mcp.Tool{
        Name:        "my_app_search",
        Title:       "Search",
        Description: "Search records owned by the current user.",
    }, func(ctx context.Context, _ *mcp.CallToolRequest, input SearchInput) (*mcp.CallToolResult, SearchOutput, error) {
        principal, err := requirePrincipal(ctx)
        if err != nil {
            return nil, SearchOutput{}, err
        }
        return nil, app.Search(ctx, principal.UserID, input), nil
    })

    handler := mcp.NewStreamableHTTPHandler(
        func(*http.Request) *mcp.Server { return server },
        &mcp.StreamableHTTPOptions{Stateless: true, JSONResponse: true},
    )
    return NewAuthenticator(app.DB, trustLazyCatHeaders()).Middleware(handler)
}
```

Auth pattern:

| Caller | Auth | Notes |
|--------|------|-------|
| LazyCat app-to-app | `X-HC-User-ID` + `X-HC-SOURCE` from platform | Trust only when env gate is enabled |
| External MCP client | `Authorization: Bearer <token>` | Token is user-bound and stored as hash |

LazyCat header trust gate:

```go
trustLazyCatHeaders := strings.EqualFold(os.Getenv("MYAPP_TRUST_LAZYCAT_HEADERS"), "true")
```

External token rules:
- Generate random 32-byte token with app prefix.
- Store SHA-256 hash only.
- Return plaintext only once from create-token API.
- Use constant-time comparison.
- Bind token to the app's internal user id.

Security rules:
- Cap list/search limits and input sizes.
- Enforce per-user ownership inside every tool.
- Redact locked/private content instead of leaking it through MCP.
- Do not log raw bearer tokens or LazyCat tickets.
- Do not expose write/delete tools until ownership and audit logging are tested.

---

## 5. Checklist

### Consumer / Gateway

- [ ] `package.yml` has `min_os_version: 1.5.2`.
- [ ] `import_resources` includes `skills` and/or `mcp-providers`.
- [ ] `lzcapp.user_delegate` is declared before calling other apps.
- [ ] Scanner reads `/lzcapp/run/resources` and tolerates missing dirs.
- [ ] `.lzcx` URLs are built from package id + relative endpoint only.
- [ ] `X-HC-USER-TICKET` is captured from real user requests.
- [ ] Dynamic tools use `<provider_slug>__<tool_name>`.

### Provider

- [ ] `POST /mcp` supports Streamable HTTP.
- [ ] `resources/mcp-providers/<provider-id>/mcp.yml` exists.
- [ ] `lzc-build.yml.resource_exports` includes `mcp-providers`.
- [ ] LazyCat header trust is behind an explicit env gate.
- [ ] External bearer tokens are hash-only and user-bound.
- [ ] Each MCP tool enforces owner isolation.
- [ ] Locked/private data is redacted.
