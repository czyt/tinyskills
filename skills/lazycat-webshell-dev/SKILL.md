---
name: lazycat-webshell-dev
description: Builds and reviews LazyCat/LightOS WebShell provider LPK apps, including lightos.webshell resource exports, provider metadata, instance selector routing, lightosctl exec/forward bridges, Catlink attach, and Publish API integration. Use when developing LazyCat WebShell providers, LightOS terminal providers, zellij/tmux webshell adapters, or debugging provider discovery and terminal connection issues.
---

# LazyCat WebShell Dev

Help developers build ordinary LazyCat LPK apps that expose a LightOS WebShell provider. Treat lightos-admin as the provider discovery and launcher surface; the provider owns its page, terminal UI, backend bridge, sessions, tabs, panes, and optional service publishing.

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

**输入**: 用户需求描述（目标实例类型、是否需要持久会话、是否有现成 Web 终端）
**输出**: 确定的 provider 类型 + 技术路线

1. Classify the provider into one of three patterns:
   - **Minimal PTY bridge**: backend runs `/lzcinit/lightosctl exec -ti '<name>@<owner_deploy_id>' /bin/sh` and bridges terminal I/O to the browser. The transport protocol is not fixed — use WebSocket (most common), gRPC-stream, connect-rpc bidirectional streaming, or SSE+POST depending on the runtime ecosystem and latency goals.
   - **Persistent terminal**: keep shell state inside the target LightOS instance with tmux, zellij, or an instance-local session manager; the provider only attaches or proxies. Attach protocol follows the same transport-agnostic principle.
   - **Existing web terminal**: run the service inside the target instance and use `lightosctl forward` plus a reverse proxy. The provider backend is a thin proxy layer.

   > ⏸️ **Checkpoint 1**: 确认 provider 分类和传输协议选择（WebSocket / gRPC-stream / connect-rpc / SSE）后再进入 Phase 2。分类错误会导致后续元数据和后端架构返工。

### Phase 2: LPK 元数据生成

**输入**: Phase 1 确定的 provider 类型
**输出**: `package.yml` + `lzc-build.yml` + `lzc-manifest.yml` + `webshell-provider.json`

2. Generate or review LPK metadata:
   - `package.yml`: declare display metadata, `permissions.required: [lightos.manage]`, and `hidden_from_launcher: true` when the provider is not useful as a standalone launcher app.
   - `lzc-build.yml`: must export `kind: lightos.webshell` from `./resources/lightos.webshell`.
   - `application.routes`: must serve the same path prefix as `webshell-provider.json.root_path`.
   - Ensure the `buildscript` in `lzc-build.yml` matches the chosen language runtime and protocol stack (e.g. Go net/http + gorilla/websocket, Node ws + grpc-js, Rust axum + tungstenite).

   > ⏸️ **Checkpoint 2**: 确认 `package.yml`（权限、隐藏标记）、`lzc-build.yml`（resource_exports、buildscript）、`root_path` 与路由一致性后再进入 Phase 3。

### Phase 3: Provider 入口合约

**输入**: Phase 2 确认的元数据
**输出**: 可被 lightos-admin 打开的 provider URL + 实例选择器

3. Implement the provider entry contract:
   - lightos-admin opens `https://<provider-domain><root_path>?name=<name>@<owner_deploy_id>`.
   - Validate `name` before using it; require exactly the `<name>@<owner_deploy_id>` selector shape.
   - List selectable instances with `/lzcinit/lightosctl ps` and prefer `status == "running"`.

   > ⏸️ **Checkpoint 3**: 用 curl 或浏览器验证入口 URL 可达、`?name=` 参数正确解析、实例列表返回 running 实例，再进入 Phase 4。

### Phase 4: 终端桥接实现

**输入**: Phase 3 验证通过的入口合约
**输出**: 可用的终端会话（shell attach / resize / disconnect 均可工作）

4. Build the terminal bridge:
   - For direct shell access, start `/lzcinit/lightosctl exec -ti selector /bin/sh` under a PTY or equivalent terminal process abstraction.
   - Source `/run/catlink/shell-env.sh` inside the instance shell when present.
   - Pass terminal `cols` and `rows` on connect, and handle resize messages such as `resize:120,32`.
   - **Protocol choice**: WebSocket is the default and most widely tested transport. When using gRPC-stream or connect-rpc, map terminal I/O to bidirectional streaming RPCs; resize events become metadata/headers on the stream frame. SSE+POST works for read-heavy terminals but adds latency on writes. Document the chosen protocol in the provider's README so operators know what to expect for proxy/load-balancer configuration.
   - Keep production Origin checks aligned with the provider's risk model and the chosen transport (WebSocket needs `Origin` header validation; gRPC needs TLS+mTLS or token auth at connection setup).

   > ⏸️ **Checkpoint 4**: 确认 shell attach、resize、disconnect/reconnect 三项均可在浏览器中正常工作，再进入 Phase 5。

### Phase 5: 可选平台 API 集成

**输入**: Phase 4 验证通过的终端桥接
**输出**: Catlink 状态 / Publish API 功能可用

5. Integrate optional platform APIs:
   - Resolve lightos-admin with `/lzcinit/lightosctl system admin-info --json`; do not ask the frontend to guess the admin domain.
   - Use only the public provider endpoints under `/unsafe_api/webshell/*` and `/unsafe_api/publish/*` unless a newer contract explicitly says otherwise.
   - Browser requests to lightos-admin must use `credentials: "include"`.

   > ⏸️ **Checkpoint 5**: 在 lightos-admin 中验证 Catlink provider 状态可见、Publish API 服务可创建/更新/删除，然后进入最终验证。

## 异常处理

Provider 在不同的 LazyCat 环境中运行，以下边界情况须在实现中覆盖，避免静默失败。

### Transport 层

| 场景 | 触发条件 | 处理方式 |
|------|----------|----------|
| WebSocket 断连 | 网络抖动、反向代理超时、浏览器挂起 | 前端实现指数退避重连（1s→2s→4s，上限 30s）；后端在 `onclose` 时清理 PTY 子进程，避免僵尸进程堆积 |
| gRPC-stream / connect-rpc 断连 | 服务端重启、TLS 证书轮换 | 客户端自动重连并恢复 stream；服务端实现 keepalive（HTTP/2 PING 帧），空闲超时 ≥ 60s |
| SSE 断连 | EventSource 默认重连、但不传自定义头 | 如需要 `credentials: "include"` 则改用 fetch+ReadableStream 或 WebSocket 替代 |
| 后端进程崩溃 | OOM、panic、编译错误 | 由 LazyCat 平台进程守护重启；provider 启动时检查 `/lzcinit/lightosctl` 和 `/run/catlink/shell-env.sh` 可用性，不可用时用明确的错误消息 fail fast 而非静默挂起 |

### 实例生命周期

| 场景 | 触发条件 | 处理方式 |
|------|----------|----------|
| 目标实例未运行 | `lightosctl ps` 返回空或 status != running | 前端展示实例状态（stopped/running），禁用非 running 实例的"连接"按钮 |
| 实例中途停止 | 用户在 lightos-admin 中停止了目标实例 | 后端检测 `lightosctl exec` 进程退出码，关闭对应终端会话并通知前端 |
| 实例被删除 | selector 对应的实例不再存在 | 返回明确错误页面或 toast，不要无限重试 |
| `lightosctl forward` 端口冲突 | 本地端口已被上一个未清理的 forward 进程占用 | 使用随机端口或递增重试（127.0.0.1:19082→19083→19084），停止时主动 kill forward 进程 |

### 权限与发现

| 场景 | 触发条件 | 处理方式 |
|------|----------|----------|
| Provider 未出现在列表 | `resource_exports` 缺失或路径错误 | 检查清单：① `lzc-build.yml` 是否有 `resource_exports[].kind: lightos.webshell` ② source 路径是否指向 `./resources/lightos.webshell` ③ `resources/lightos.webshell/default/webshell-provider.json` 是否存在 ④ LPK 是否已安装到目标环境 |
| `lightos.manage` 缺失 | `package.yml` 未声明权限 | `lightosctl ps` 和 `lightosctl exec` 需要此权限；添加到 `permissions.required` 后重新构建 LPK |
| `admin-info` 返回空 | 非 LazyCat 环境或版本过旧 | 回退：引导用户手动输入 lightos-admin URL；检查 `min_os_version` 是否匹配 |

### 协议选择决策

| 协议 | 适用场景 | 主要限制 |
|------|---------|---------|
| WebSocket | 默认选择，浏览器原生支持，生态成熟 | 需要处理 proxy/load-balancer 的 WebSocket 升级头；长连接需心跳 |
| gRPC-stream (Web) | 已有 gRPC 基础设施的团队，需要强类型契约 | 需要 gRPC-Web proxy（Envoy/grpcweb）；浏览器端 bundle 体积较大 |
| connect-rpc | 兼容 gRPC 协议 + HTTP/1.1 fallback，浏览器友好 | 相对较新，Go/Node 生态成熟度低于 WebSocket |
| SSE + POST | 单向推送场景（日志流、状态更新） | 写操作走独立 POST，延迟高于双向流；不适合交互式终端 |

## Verification

Run the smallest checks that prove the claim. Use the language's normal unit/build command plus LazyCat packaging:

```bash
# run the implementation's normal unit/build checks first
lzc-cli project release
```

Then install the generated LPK and verify:

- provider appears in lightos-admin's WebShell provider list;
- opened URL includes `?name=<name>@<owner_deploy_id>`;
- shell attach, resize, reconnect, and instance switching work;
- transport disconnect scenario: kill the backend process, confirm reconnect succeeds within 30s;
- Catlink status and Publish API actions work when implemented.

For the language-neutral protocol, version notes, and failure diagnosis, see [references/provider-contract.md](references/provider-contract.md). For complete runnable examples, see [references/examples.md](references/examples.md).
