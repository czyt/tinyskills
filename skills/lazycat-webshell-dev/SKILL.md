---
name: lazycat-webshell-dev
description: Use when developing or reviewing LazyCat/LightOS WebShell provider LPK apps, debugging provider discovery, launch URL, session restore, mobile terminal UX, lightos-admin return navigation, Catlink, lightosctl exec/forward, Publish API, or zellij/tmux/web terminal adapters. 触发词：开发WebShell provider、WebShell调试、LightOS终端、会话恢复、手机终端、lightosctl桥接。
---

# LazyCat WebShell Dev

Build language-neutral LazyCat LPK apps that expose a LightOS WebShell provider. Treat lightos-admin as the discovery, launcher, account boundary, and return surface. Treat `lazycat-microserver-webshell` as a source-proven reference for principles, not as a Go-only template.

## Target Model

The clean model is: **LightOS owns discovery and authorization; the target instance owns durable terminal state; the provider owns UX, routing, and stream brokerage.**

Do not design the provider as a standalone SSH terminal. A WebShell provider is an account-scoped LightOS adapter with four contracts:

- **Discovery contract**: LPK metadata exports `lightos.webshell`, and lightos-admin opens `?name=<name>@<owner_deploy_id>`.
- **Command boundary**: all instance work goes through `/lzcinit/lightosctl`; the provider never guesses instance filesystem/network access.
- **Session contract**: stable selector/account/tab/pane IDs plus state/action/activity/attach endpoints keep UI and terminal streams reattachable.
- **UX contract**: browser terminal controls are first-class product surface, especially on mobile; they are not just a canvas and a WebSocket.

## Quick Start

Create a normal LPK app. The backend can use any runtime with commands, JSON, HTTP/streaming, and optional PTY support.

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

## Quick Reference

| Need | Required Pattern |
| --- | --- |
| Provider discovery | `resource_exports[].kind: lightos.webshell` plus `resources/lightos.webshell/default/webshell-provider.json` |
| Launch contract | `https://<provider-domain><root_path>?name=<name>@<owner_deploy_id>` |
| Account boundary | Validate selector shape, then authorize it against `lightosctl ps` and the current LightOS account/deploy ID |
| Same-page return | Resolve admin URL in backend, preserve workspace, then same-page `location.assign()` |
| Session owner | Keep durable workspace/session state inside the target instance or an instance-local session manager; provider backend is launcher/proxy |
| Multi-device consistency | One pane has one raw byte stream: append output to bounded history, broadcast the same chunks to attached clients, replay history with selector+pane identity before live output |
| Session restore | `GET state` -> rebuild tabs/panes -> `ATTACH stream`; queue user input until `history-replay-complete`, reject mismatched replay, suppress duplicate generated terminal responses |
| Key mapping | Terminal bytes and mobile ANSI/CSI shortcuts go to backend as `input`; UI shortcuts call workspace actions locally |
| VT boundary | Frontend parses/renders VT; backend relays raw PTY bytes |
| UX abstraction | Separate terminal byte path, workspace action path, frontend-only actions, and platform navigation |
| Mobile terminal | Safe-area layout, visual viewport, touch shortcuts, IME-safe input, touch selection, no hover-only controls |
| LightOS commands | Use `ps`, `system admin-info --json`, `exec`, optional `forward`, and public admin APIs for Publish/Catlink |

## Workflow

### Phase 1: 分类与确认

1. Classify the provider into one of three patterns:
   - **Minimal PTY bridge**: run `/lzcinit/lightosctl exec -ti '<name>@<owner_deploy_id>' /bin/sh` and bridge terminal I/O. Use WebSocket, gRPC-stream, connect-rpc, or SSE+POST by runtime fit.
   - **Persistent terminal**: keep tabs, panes, history, cwd, and commands in the target instance or an instance-local agent; tmux/zellij are valid implementations, not requirements.
   - **Existing web terminal**: run the service inside the target instance and use `lightosctl forward` plus a reverse proxy. The provider backend is a thin proxy layer.

   > ⏸️ **Checkpoint 1**: 确认 provider 分类和传输协议选择后再进入 Phase 2。分类错误将导致后续返工。

### Phase 2: LPK 元数据生成

2. Generate or review LPK metadata:
   - `package.yml`: declare display metadata and `permissions.required: [lightos.manage]`. Use `hidden_from_launcher: true` only for provider-only apps; omit it when the app can open standalone by selecting a default running instance.
   - `lzc-build.yml`: must export `kind: lightos.webshell` from `./resources/lightos.webshell`.
   - `application.routes`: must serve the same path prefix as `webshell-provider.json.root_path`.
   - `lzc-manifest.yml`: enable `application.multi_instance: true` for per-deployment workspace state or instance filtering.
   - Ensure the `buildscript` matches the chosen runtime and protocol stack.

   > ⏸️ **Checkpoint 2**: 确认 package.yml（权限、隐藏标记）、lzc-build.yml（resource_exports、buildscript）、manifest multi-instance、root_path 与路由一致。

### Phase 3: Provider 入口合约

3. Implement the provider entry contract:
   - lightos-admin opens `https://<provider-domain><root_path>?name=<name>@<owner_deploy_id>`.
   - Validate `name` before using it; require exactly the `<name>@<owner_deploy_id>` selector shape and never drop `owner_deploy_id`.
   - Authorize the selector against the current account/deploy context on every list, attach, forward, publish, and restore path.
   - List selectable instances with `/lzcinit/lightosctl ps` and prefer `status == "running"`.
   - Add same-page return: resolve `admin-info --json`, build `<base_url>?view=home`, fallback to trusted `document.referrer`, preserve tab/session, suppress intentional unload prompts, then `location.assign()`.

   > ⏸️ **Checkpoint 3**: 验证入口 URL 可达、`?name=` 参数解析正确、账号隔离生效、同页返回 LightOS 首页可用。

### Phase 4: 终端桥接、会话保持与多端一致性

4. Build the terminal bridge and session model:
   - For direct shell access, start `/lzcinit/lightosctl exec -ti selector /bin/sh -lc <bootstrap>` under a PTY or equivalent terminal process abstraction.
   - Source `/run/catlink/shell-env.sh` inside the instance shell when present.
   - Pass terminal `cols` and `rows` on connect, and handle resize messages such as `resize:120,32`.
   - Choose WebSocket (default), gRPC-stream, connect-rpc, or SSE+POST and map terminal I/O to streaming.
   - Match Origin/auth checks to the transport: WebSocket → `Origin` header validation; gRPC → TLS+mTLS or token auth at connection setup.
   - Use workspace state keyed by authorized selector/account. Minimal restore contract: `GET state`, `POST action`, `GET activity`, `ATTACH stream` with stable `tab_id` and `pane_id`.
   - Make the target instance or instance-local agent the session authority. The provider process may restart; tab/pane/process state must still be discoverable or reattachable.
   - On PTY output, append filtered raw bytes to bounded per-pane history, then broadcast the same chunks to every attached client. This is what makes multiple browser tabs/devices converge on the same terminal output.
   - Restore UI from state before attaching streams. Replay buffered output between `history-replay-start` and `history-replay-complete` frames that include selector and pane identity; reject mismatched replay.
   - During replay, allow generated terminal responses from only the intended client. Secondary clients must suppress generated cursor/device-status responses so multiple renderers do not all write answers back into the shared PTY.
   - Queue input until replay completes, cap buffers, reconnect visible panes on online/focus/visibility, and preserve active tab across reloads.
   - Treat terminal resize as a shared PTY decision: the active device may change wrapping for passive viewers. Document this, or add a collaboration policy if simultaneous typing/viewing matters.
   - Lock input on server revision changes, intentional reloads, and attach recovery; clear the lock only after the refreshed client reconnects and replay completes.
   - Keep key mapping explicit: terminal/text/paste/mobile bytes become `{type:"input",data}`; resize/input-lock/detach are control messages; tab/split/close/rename shortcuts call workspace actions.
   - Keep VT implementation single-owner: frontend renderer by default; backend headless VT only for search/snapshot/collaboration needs.

   > ⏸️ **Checkpoint 4**: 验证 shell attach、resize、history replay、刷新恢复、网络断连恢复、升级后输入锁与重连。

### Phase 5: 移动端体验

5. Make the browser terminal usable on touch devices:
   - Layout: viewport-fit, safe-area insets, `dvh` or visual viewport variables, and provider-owned navigation if platform chrome is hidden.
   - Input: touch shortcuts for Tab/Return/arrows/Esc/modifiers/copy/paste/search/tab actions; no hover, right-click, or hardware-keyboard dependency.
   - IME: keep composition text in preview/state, send only committed text, dedupe post-composition input, and reset textarea/host scroll after composition.
   - Gestures: long-press selection handles, action sheets, tab overview, side/back guard for overlays, and close confirmations for running panes.
   - Feedback: visible connection state, retryable startup errors, offline/online banners, and nonblocking toasts for agent upgrade notices.
   - Resize/reassert terminal cols/rows after orientation, focus, keyboard, visibility, and online/offline changes.

   > ⏸️ **Checkpoint 5**: 在手机浏览器验证软键盘、中文输入、快捷键、选择复制、横竖屏、返回键、离线重连。

### Phase 6: 可选平台 API 集成

6. Integrate optional platform APIs:
   - Resolve lightos-admin with `/lzcinit/lightosctl system admin-info --json`; do not ask the frontend to guess the admin domain.
   - Use `/lzcinit/lightosctl ps` to list instances and build selectors; use `exec` for shell/files/agent requests; use `forward` only when adapting an existing in-instance web terminal.
   - Use only the public provider endpoints under `/unsafe_api/webshell/*` and `/unsafe_api/publish/*` unless a newer contract explicitly says otherwise.
   - Browser requests to lightos-admin must use `credentials: "include"`.

   Command/API roles to model explicitly:

   | Command/API | Why it exists |
   | --- | --- |
   | `/lzcinit/lightosctl ps` | Discover instances and selector fields; validate requested selector against current visibility |
   | `/lzcinit/lightosctl system admin-info --json` | Resolve admin `base_url`/deploy ID for return navigation, Publish/Catlink proxying, and deploy fallback |
   | `/lzcinit/lightosctl exec <selector> ...` | Enter the target instance for shell, file, agent, process scan, and revision marker work |
   | `/lzcinit/lightosctl exec -i <selector> ...` | Stream noninteractive stdin/stdout for agent attach, file upload/download, and tar install |
   | `/lzcinit/lightosctl exec -ti <selector> ...` | Allocate an interactive PTY shell for minimal bridge mode |
   | `/lzcinit/lightosctl forward ... <selector>` | Proxy an existing web terminal or service already running inside the target instance when using an adapter architecture |

   > ⏸️ **Checkpoint 6**: 在 lightos-admin 中确认 Catlink 状态可见、Publish API 可创建/更新/删除。

## 异常处理

Provider 在异构 LazyCat 环境中运行，以下边界情况须覆盖，避免静默失败。

| 场景 | 处理方式 |
|------|----------|
| **WebSocket 断连**（网络抖动、代理超时） | 前端指数退避重连（1s→2s→4s，上限 30s）；后端 `onclose` 清理 PTY 子进程 |
| **gRPC / connect-rpc 断连**（服务重启、TLS 轮换） | 客户端自动重连恢复 stream；服务端 keepalive（HTTP/2 PING），空闲超时 ≥ 60s |
| **后端进程崩溃**（OOM、panic） | 平台进程守护重启；启动时检查 `lightosctl` 和 shell-env.sh 可用性，不可用时 fail fast |
| **目标实例未运行** | 前端禁用非 running 实例的"连接"按钮，展示实例状态 |
| **实例中途停止** | 检测 `lightosctl exec` 退出码，关闭终端会话并通知前端 |
| **实例被删除** | 返回明确错误页面，不无限重试 |
| **账号/实例串线** | 所有 state/action/ws/forward/publish 请求都重新校验 selector 属于当前账号 |
| **历史回放串线** | replay 控制帧携带 selector + pane_id；客户端不匹配就关闭连接并重新拉取 state |
| **刷新/升级丢会话** | tab/pane ID 放 URL/storage；revision 变化前锁输入并提示刷新 |
| **同页返回失败** | 优先 admin-info base_url，fallback 到跨源 referrer；禁止硬编码域名或 `window.open` 新页 |
| **移动端软键盘遮挡** | 使用 visual viewport + safe-area + 重新 resize |
| **移动端 IME 重复输入** | composition 文本单独预览，提交后再写入终端；禁止把中间态反复发送 |
| **forward 端口冲突** | 递增重试（19082→19083→19084），停止时主动 kill forward 进程 |
| **Provider 未出现在列表** | ① `resource_exports[].kind: lightos.webshell` ② source → `./resources/lightos.webshell` ③ `default/webshell-provider.json` 存在 ④ LPK 已安装 |
| **`lightos.manage` 权限缺失** | `lightosctl ps/exec` 需此权限；添加到 `permissions.required` 后重建 LPK |
| **`admin-info` 返回空** | 回退：引导用户手动输入 admin URL；检查 `min_os_version` |

传输协议偏好：**WebSocket**（默认） > **gRPC-stream**（需要 gRPC-Web proxy）> **connect-rpc**（HTTP/1.1 fallback 友好）。SSE+POST 仅用于日志流等单向推送场景，不适合交互式终端。

## What Not To Copy Blindly

| Temptation | Better abstraction |
| --- | --- |
| "The reference is Go, so the skill is for Go" | The protocol needs HTTP/streaming, process execution, JSON, and optional PTY; any runtime can implement that. |
| "Use tmux/zellij because sessions must persist" | They are optional session backends. The core requirement is instance-local session authority plus stable state/action/attach contracts. |
| "Every client owns its own terminal truth" | One pane owns one raw output history and live byte stream. Clients render that stream and validate replay identity. |
| "Forward terminal control bytes through shortcuts" | UI actions modify workspace state; only terminal input bytes go to stdin. |
| "Let the frontend guess LightOS URLs" | Backend resolves admin info through `lightosctl`; frontend consumes a provider API. |
| "Mobile is just responsive CSS" | Mobile WebShell requires keyboard, IME, selection, viewport, reconnect, and navigation behavior. |

## Verification

Build and install, then verify the smallest checks that prove the claim:

```bash
lzc-cli project release
```

- provider in lightos-admin's WebShell list; URL includes `?name=<name>@<owner_deploy_id>`
- shell attach, resize, reconnect, instance switching work; disconnect/reconnect within 30s
- refresh/reopen restores active instance, tab, pane, history replay, cwd/command metadata, and pending input behavior
- open the same pane from two browser tabs/devices; both receive the same history replay and live output, reject mismatched selector/pane replay, and do not accept input before replay completes
- same-page return lands on LightOS home and preserves provider state when the user comes back
- mobile checks cover soft keyboard, IME, shortcuts, selection, browser back, safe areas, orientation, and offline/online
- Catlink status and Publish API actions work when implemented.

For protocol details, version notes, and failure diagnosis: [provider-contract.md](references/provider-contract.md). For runnable examples: [examples.md](references/examples.md).
