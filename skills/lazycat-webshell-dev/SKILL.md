---
name: lazycat-webshell-dev
description: Builds and reviews LazyCat/LightOS WebShell provider LPK apps, including lightos.webshell resource exports, provider metadata, instance selector routing, lightosctl exec/forward bridges, Catlink attach, and Publish API integration. Use when developing LazyCat WebShell providers, LightOS terminal providers, zellij/tmux webshell adapters, or debugging provider discovery and terminal connection issues. 触发词：开发WebShell provider、WebShell调试、LightOS终端、zellij/tmux适配、lightosctl桥接。
---

# LazyCat WebShell Dev

Build LazyCat LPK apps that expose a LightOS WebShell provider, with lightos-admin as the discovery and launcher surface.

## Quick Start

Create a normal LPK app with these required pieces. The provider backend can be written in any language that can run commands, parse JSON, serve HTTP plus a bidirectional transport (WebSocket, gRPC-stream, connect-rpc, or SSE+POST), and optionally allocate a PTY.

```text
package.yml
lzc-build.yml
lzc-manifest.yml
resources/lightos.webshell/default/webshell-provider.json
backend service in Go, Node.js, Rust, Python, etc.
runtime/ or frontend assets
```

Minimum provider declaration:

```yaml
# lzc-build.yml
resource_exports:
  - kind: lightos.webshell
    source: ./resources/lightos.webshell
```

```json
{
  "support_home": false,
  "root_path": "/"
}
```

## Workflow

### Phase 1: 分类与确认

1. Classify the provider into one of three patterns:
   - **Minimal PTY bridge**: backend runs `/lzcinit/lightosctl exec -ti '<name>@<owner_deploy_id>' /bin/sh` and bridges terminal I/O to the browser. The transport protocol is not fixed — use WebSocket (most common), gRPC-stream, connect-rpc bidirectional streaming, or SSE+POST depending on the runtime ecosystem and latency goals.
   - **Persistent terminal**: keep shell state inside the target LightOS instance with tmux, zellij, or an instance-local session manager; the provider only attaches or proxies. Attach protocol follows the same transport-agnostic principle.
   - **Existing web terminal**: run the service inside the target instance and use `lightosctl forward` plus a reverse proxy. The provider backend is a thin proxy layer.

   > ⏸️ **Checkpoint 1**: 确认 provider 分类和传输协议选择后再进入 Phase 2。分类错误将导致后续返工。

### Phase 2: LPK 元数据生成

2. Generate or review LPK metadata:
   - `package.yml`: declare display metadata, `permissions.required: [lightos.manage]`, and `hidden_from_launcher: true` when the provider is not useful as a standalone launcher app.
   - `lzc-build.yml`: must export `kind: lightos.webshell` from `./resources/lightos.webshell`.
   - `application.routes`: must serve the same path prefix as `webshell-provider.json.root_path`.
   - Ensure the `buildscript` in `lzc-build.yml` matches the chosen language runtime and protocol stack (e.g. Go net/http + gorilla/websocket, Node ws + grpc-js, Rust axum + tungstenite).

   > ⏸️ **Checkpoint 2**: 确认 package.yml（权限、隐藏标记）、lzc-build.yml（resource_exports、buildscript）、root_path 与路由一致。

### Phase 3: Provider 入口合约

3. Implement the provider entry contract:
   - lightos-admin opens `https://<provider-domain><root_path>?name=<name>@<owner_deploy_id>`.
   - Validate `name` before using it; require exactly the `<name>@<owner_deploy_id>` selector shape.
   - List selectable instances with `/lzcinit/lightosctl ps` and prefer `status == "running"`.

   > ⏸️ **Checkpoint 3**: 验证入口 URL 可达、`?name=` 参数解析正确、实例列表返回 running 实例。

### Phase 4: 终端桥接实现

4. Build the terminal bridge:
   - For direct shell access, start `/lzcinit/lightosctl exec -ti selector /bin/sh` under a PTY or equivalent terminal process abstraction.
   - Source `/run/catlink/shell-env.sh` inside the instance shell when present.
   - Pass terminal `cols` and `rows` on connect, and handle resize messages such as `resize:120,32`.
   - Choose a bidirectional transport: WebSocket (default, most tested), gRPC-stream, connect-rpc, or SSE+POST. Map terminal I/O to the transport's native streaming model; see [协议选择决策](#协议选择决策) below for trade-offs.
   - Match Origin/auth checks to the transport: WebSocket → `Origin` header validation; gRPC → TLS+mTLS or token auth at connection setup.

   > ⏸️ **Checkpoint 4**: 验证 shell attach、resize、disconnect/reconnect 三项均可工作。

### Phase 5: 可选平台 API 集成

5. Integrate optional platform APIs:
   - Resolve lightos-admin with `/lzcinit/lightosctl system admin-info --json`; do not ask the frontend to guess the admin domain.
   - Use only the public provider endpoints under `/unsafe_api/webshell/*` and `/unsafe_api/publish/*` unless a newer contract explicitly says otherwise.
   - Browser requests to lightos-admin must use `credentials: "include"`.

   > ⏸️ **Checkpoint 5**: 在 lightos-admin 中确认 Catlink 状态可见、Publish API 可创建/更新/删除。

## 异常处理

Provider 在异构 LazyCat 环境中运行，以下边界情况须覆盖，避免静默失败。

| 场景 | 处理方式 |
|------|----------|
| **WebSocket 断连**（网络抖动、代理超时） | 前端指数退避重连（1s→2s→4s，上限 30s）；后端 `onclose` 清理 PTY 子进程 |
| **gRPC / connect-rpc 断连**（服务重启、TLS 轮换） | 客户端自动重连恢复 stream；服务端 keepalive（HTTP/2 PING），空闲超时 ≥ 60s |
| **SSE 断连**（需要 credentials） | EventSource 不传自定义头 → 改用 fetch+ReadableStream 或退回到 WebSocket |
| **后端进程崩溃**（OOM、panic） | 平台进程守护重启；启动时检查 `lightosctl` 和 shell-env.sh 可用性，不可用时 fail fast |
| **目标实例未运行** | 前端禁用非 running 实例的"连接"按钮，展示实例状态 |
| **实例中途停止** | 检测 `lightosctl exec` 退出码，关闭终端会话并通知前端 |
| **实例被删除** | 返回明确错误页面，不无限重试 |
| **forward 端口冲突** | 递增重试（19082→19083→19084），停止时主动 kill forward 进程 |
| **Provider 未出现在列表** | ① `resource_exports[].kind: lightos.webshell` ② source → `./resources/lightos.webshell` ③ `default/webshell-provider.json` 存在 ④ LPK 已安装 |
| **`lightos.manage` 权限缺失** | `lightosctl ps/exec` 需此权限；添加到 `permissions.required` 后重建 LPK |
| **`admin-info` 返回空** | 回退：引导用户手动输入 admin URL；检查 `min_os_version` |

传输协议偏好：**WebSocket**（默认） > **gRPC-stream**（需要 gRPC-Web proxy）> **connect-rpc**（HTTP/1.1 fallback 友好）。SSE+POST 仅用于日志流等单向推送场景，不适合交互式终端。
## Verification

Build and install, then verify the smallest checks that prove the claim:

```bash
lzc-cli project release
```

- provider in lightos-admin's WebShell list; URL includes `?name=<name>@<owner_deploy_id>`
- shell attach, resize, reconnect, instance switching work; disconnect/reconnect within 30s
- Catlink status and Publish API actions work when implemented.

For protocol details, version notes, and failure diagnosis: [provider-contract.md](references/provider-contract.md). For runnable examples: [examples.md](references/examples.md).
