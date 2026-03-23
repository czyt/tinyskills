# Script Injection (injects) Reference

`injects` lets you adapt application behavior without changing OCI images or upstream source code, by injecting scripts into browser, request, or response phases.

## Use Cases

- **Password autofill and auto-login** - See Passwordless Login guide
- **CORS/CSP fine tuning** - Add/remove response headers
- **Replace browser file dialog** - With LazyCat storage flow
- **Hide/modify page elements** - Without upstream source changes
- **Advanced routing** - Dynamic reverse proxy via `ctx.proxy`
- **Request/response fixes** - Headers, WebSocket details
- **User-scoped persistence** - With `ctx.persist`
- **Request-level troubleshooting** - With `ctx.dump`

---

## Phases and Runtime

Each inject belongs to exactly one phase:

| Phase | Runtime | Description |
|-------|---------|-------------|
| `on=browser` | Browser | Runs in real browser runtime |
| `on=request` | lzcinit sandbox | Before upstream forwarding |
| `on=response` | lzcinit sandbox | After upstream response |

### Execution Order

1. By `application.injects` declaration order
2. Then by `do[]` order inside each inject
3. Match strategy: `all-match-run` within same phase

### Short-circuit Behavior

- In `request/response`, once `ctx.response.send()` or `ctx.proxy.to()` takes effect, remaining scripts stop
- Any script error stops current phase immediately

---

## Matching Rules

### Fields

| Field | Description |
|-------|-------------|
| `when` | OR match rules; any matched rule enters candidate set |
| `unless` | OR exclude rules; any matched rule rejects candidate |
| `prefix_domain` | Host prefix filter (`<prefix>-...`) |
| `auth_required` | Default `true`; skip when no valid `SAFE_UID` |

### Rule Format

```
<path-pattern>[?<query>][#<hash-pattern>]
```

### Examples

| Rule | Matches |
|------|---------|
| `"/"` | Root only |
| `"/*"` | Any path |
| `"/api/*?v=2"` | `/api/` prefix + query contains `v=2` |
| `"/#login"` | Hash equals `login` (browser only) |

**Note:** `#hash` is only supported in `browser` phase, not in `request/response`.

---

## Manifest Example

```yaml
application:
  injects:
    - id: login-autofill
      when:
        - /#login
        - /#signin
      do:
        - src: builtin://hello
          params:
            message: "hello world"

    - id: inject-basic-auth-header
      auth_required: false
      on: request
      when:
        - /api/*
      do: |
        ctx.headers.set("Authorization", "Basic " + ctx.base64.encode("admin:admin123"));

    - id: remove-cors
      on: response
      when:
        - /api/*
      unless:
        - /api/admin/*
      do: |
        ctx.headers.del("Access-Control-Allow-Origin");
        ctx.headers.del("Access-Control-Allow-Credentials");
```

---

## `do` Syntax

Two forms supported:

### Short Syntax

```yaml
do: |
  console.log("Hello from inject");
```

### Long Syntax

```yaml
do:
  - src: |
      console.log("First action");
  - src: builtin://simple-inject-password
    params:
      username: admin
```

---

## `ctx` Overview

### Common Fields (All Phases)

```javascript
ctx.id           // Inject ID
ctx.src         // Script source
ctx.phase       // Current phase
ctx.params      // Inject params
ctx.safe_uid    // Current user's SAFE_UID
ctx.request.host
ctx.request.path
ctx.request.raw_query
```

### Browser-Only Fields

```javascript
ctx.request.hash              // URL hash
ctx.runtime.executedBefore    // Boolean
ctx.runtime.executionCount    // Number
ctx.runtime.trigger           // Trigger type
ctx.persist                   // Promise API for persistence
```

### Request/Response Helpers

```javascript
ctx.headers      // Header manipulation
ctx.body         // Body access
ctx.flow         // Flow control
ctx.persist      // User-scoped persistence
ctx.response     // Response manipulation
ctx.proxy        // Proxy control
ctx.base64       // Base64 utilities
ctx.fs           // File system access
ctx.dump         // Debug dumping
```

---

## Frontend Dev Proxy Pattern

Inject that proxies to dev machine frontend server:

```yaml
application:
  routes:
    - /=file:///lzcapp/pkg/content/dist
#@build if env.DEV_MODE=1
  injects:
    - id: frontend-dev-proxy
      on: request
      auth_required: false
      when:
        - "/*"
      do:
        - src: |
            const devPort = 3000;
            const contentType = "text/html; charset=utf-8";

            function renderDevPage(title, subtitle, steps) {
              const items = steps.map(function (step) {
                return "<li>" + step + "</li>";
              }).join("");
              return [
                "<!doctype html>",
                "<html><head><meta charset=\"UTF-8\"><title>Dev</title></head>",
                "<body><h1>", title, "</h1><p>", subtitle, "</p><ol>", items, "</ol></body></html>",
              ].join("");
            }

            if (!ctx.dev.id) {
              ctx.response.send(200, renderDevPage(
                "Dev machine not linked",
                "Waiting for frontend dev server.",
                ["Run lzc-cli project deploy", "Start npm run dev"]
              ), { content_type: contentType });
              return;
            }

            const via = ctx.net.via.client(ctx.dev.id);
            if (!ctx.dev.online()) {
              ctx.response.send(200, renderDevPage(
                "Dev machine offline",
                "The linked dev machine is not reachable.",
                ["Bring dev machine online", "Start npm run dev"]
              ), { content_type: contentType });
              return;
            }

            if (!ctx.net.reachable("tcp", "127.0.0.1", devPort, via)) {
              ctx.response.send(200, renderDevPage(
                "Frontend dev server not ready",
                "Waiting for port " + devPort,
                ["Start npm run dev on port " + devPort]
              ), { content_type: contentType });
              return;
            }

            ctx.proxy.to("http://127.0.0.1:" + devPort, {
              via: via,
              use_target_host: true,
            });
#@build end
```

---

## Backend Dev Guide Pattern

Inject that shows guide page until backend is ready:

```yaml
application:
#@build if env.DEV_MODE!=1
  routes:
    - /=exec://3000,/app/run.sh
#@build end
#@build if env.DEV_MODE=1
  injects:
    - id: backend-dev-proxy
      on: request
      auth_required: false
      when:
        - "/*"
      do:
        - src: |
            const backendPort = 3000;
            const backendURL = "http://127.0.0.1:" + backendPort;

            if (!ctx.net.reachable("tcp", "127.0.0.1", backendPort)) {
              ctx.response.send(200, [
                "<!doctype html><html><body>",
                "<h1>Backend not ready</h1>",
                "<ol>",
                "<li>Run lzc-cli project sync --watch</li>",
                "<li>Run lzc-cli project exec /bin/sh</li>",
                "<li>Start backend: /app/run.sh</li>",
                "</ol></body></html>",
              ].join(""), { content_type: "text/html" });
              return;
            }

            ctx.proxy.to(backendURL, { use_target_host: true });
#@build end
```

---

## Built-in Scripts

| Script | Purpose |
|--------|---------|
| `builtin://simple-inject-password` | Password autofill |
| `builtin://hello` | Test inject execution |

---

## Debug Tips

### Add Debug Headers

```javascript
ctx.headers.set("X-Debug-Dev-ID", ctx.dev.id || "");
ctx.headers.set("X-Debug-Dev-Online", String(ctx.dev.online()));
```

### Recommended Debug Order

1. Check if inject matches current path
2. Check if `ctx.dev.id` is empty
3. Check if `ctx.dev.online()` is true
4. Check if `ctx.net.reachable()` is true
5. Check if `ctx.proxy.to()` uses correct `via`

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `#hash` in `on=request/response` | `#hash` only works in browser phase |
| Expecting inject to run without `SAFE_UID` | Set `auth_required: false` |
| Calling `ctx.body.getJSON()` on non-JSON | Add error handling |
| Forgetting `return` after `ctx.response.send()` | Add `return;` to stop execution |