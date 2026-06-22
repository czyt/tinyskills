# LazyCat WebShell Provider Contract

This reference distills `webshell-provider-examples` plus the `lazycat-microserver-webshell` source into reusable implementation rules for LazyCat/LightOS WebShell providers.

## Stable Contract

WebShell providers are normal LPK apps. The protocol is language-neutral: any backend runtime can implement it if it can serve HTTP, handle WebSocket or streaming transport, run `lightosctl`, parse JSON, and manage processes or PTYs when terminal bridging is needed.

lightos-admin discovers installed providers through `resource_exports`, then opens the provider entry URL in the current browser context with a LightOS instance selector:

```text
https://<provider-domain><root_path>?name=<name>@<owner_deploy_id>
```

The provider must not depend on lightos-admin source code, private routes, or internal frontend state. The public contract is the provider app URL plus the `name` query parameter; everything else should be resolved through documented platform commands or public endpoints.

The `lazycat-microserver-webshell` source proves a useful target model: the provider backend launches and brokers streams, while a target-instance agent owns workspace/session state. That agent happens to be compiled from Go in the reference project, but the model is runtime-neutral: any language can implement the same state/action/activity/attach protocol and run it inside the target instance.

## Required Files

```text
package.yml
lzc-build.yml
lzc-manifest.yml
resources/
  lightos.webshell/
    default/
      webshell-provider.json
backend executable or script in any language
frontend/runtime assets
```

`resources/lightos.webshell/default/webshell-provider.json`:

```json
{
  "support_home": false,
  "root_path": "/"
}
```

Field rules:

| Field | Rule |
| --- | --- |
| `support_home` | Third-party providers normally use `false`; implement any return-home UX inside the provider page. |
| `root_path` | Must start with `/`; it is appended to the provider app domain before `?name=...`. |

If `root_path` is `/webshell/`, the backend must serve that prefix and assets/WebSocket/API paths must work under it. Prefer relative frontend URLs to reduce prefix bugs.

## LPK Metadata

Minimal `package.yml` shape:

```yaml
package: cloud.lazycat.webshell.example
version: 0.1.0
name: Example WebShell
description: Example LightOS WebShell provider
min_os_version: v1.5.2
permissions:
  required:
    - lightos.manage
locales:
  zh:
    name: 示例 WebShell
    description: LightOS WebShell provider 示例
```

Launcher visibility is a product decision:

| Case | `hidden_from_launcher` |
| --- | --- |
| Provider-only app that cannot choose a default instance and only works with `?name=` from lightos-admin | `true` |
| Full WebShell app that can open standalone, pick a running default instance, switch instances, and expose settings | omit or set `false` |

The `lazycat-microserver-webshell` reference omits `hidden_from_launcher` because it supports standalone launch: if `?name=` is missing, the frontend loads instances, selects a running instance, writes the selector back into the URL, and then restores workspace state.

Use `application.multi_instance: true` when the provider stores per-deployment workspace state, filters instances by deploy ID, or should behave differently for different installed copies. Multi-instance does not replace selector authorization; it only scopes the provider deployment.

Minimal `lzc-build.yml` shape:

```yaml
contentdir: ./dist/content
resource_exports:
  - kind: lightos.webshell
    source: ./resources/lightos.webshell
```

Minimal route:

```yaml
application:
  subdomain: example-webshell
  routes:
    - /=exec://8080,/lzcapp/pkg/content/example-webshell
```

If the route prefix is not `/`, keep it consistent with `root_path`.

Add a `buildscript` that matches the implementation language and packaging model:

- Node.js: build frontend/backend assets and copy the Node entrypoint plus dependencies or bundled output.
- Rust: compile a Linux amd64 binary with the project toolchain and copy it to `contentdir`.
- Python: copy application files and ensure the runtime image/environment used by the LPK can execute them.

Do not encode Go-specific assumptions into `webshell-provider.json`, URL handling, selector parsing, Catlink, or Publish API behavior.

Complete implementation examples: [examples.md](examples.md).

## Instance Selector

List instances from the provider backend:

```sh
/lzcinit/lightosctl ps
```

The output is a JSON array with fields such as `name`, `owner_deploy_id`, and `status`. Build the selector as:

```text
<name>@<owner_deploy_id>
```

Validation requirements:

- reject empty selectors;
- require both sides of `@`;
- pass the full selector to `lightosctl`;
- filter or visually disable instances whose `status` is not `running`.
- authorize the selector against the current account/deploy context on every state, action, stream, forward, and publish request.

Authorization requirements:

- use the platform-provided current user/account signal when available, such as an account header injected by LightOS;
- compare requested selector against `/lzcinit/lightosctl ps`;
- prefer filtering by current provider deploy ID, then fall back to `admin-info.deploy_id` if the environment deploy ID is missing or stale;
- return `401` for missing account context, `403` for cross-account selectors, and `400` for malformed selectors.

## LightOS Command Boundary

The provider should have a narrow platform-command boundary. Keep these calls server-side so the frontend never guesses LightOS internals.

| Operation | Command/API | Why it exists | Guardrail |
| --- | --- | --- | --- |
| Discover instances | `/lzcinit/lightosctl ps` | Produces `name`, `owner_deploy_id`, `status`, optional `username`; source of selector truth | Parse JSON; never invent selectors client-side |
| Resolve admin | `/lzcinit/lightosctl system admin-info --json` | Provides `base_url` and deploy ID for return navigation, Catlink, Publish proxy, and owner fallback | Validate `http/https` scheme and host before use |
| Minimal PTY | `/lzcinit/lightosctl exec -ti <selector> /bin/sh -lc <bootstrap>` | Allocates an interactive shell in the target instance | Validate selector and account before spawning |
| Noninteractive IO | `/lzcinit/lightosctl exec -i <selector> ...` | Streams tar/file/agent attach stdin/stdout without terminal allocation | Cap payloads; close stdin on detach |
| Agent request | `/lzcinit/lightosctl exec <selector> <agent-bin> agent request ...` | Sends state/action/activity RPC to the instance-local session authority | Include selector + account in every request |
| Process/activity scan | `/lzcinit/lightosctl exec <selector> /bin/sh -lc <proc-scan>` | Reads cwd/command/busy metadata for panes | Treat scan failure as metadata degradation, not terminal death |
| Existing web terminal | `/lzcinit/lightosctl forward -L local:remote <selector>` | Proxies an in-instance web UI such as zellij Web or a custom service | Tie lifecycle to selected instance and kill stale forwards |
| Admin platform API | `/unsafe_api/webshell/*`, `/unsafe_api/publish/*` | Catlink status/attach and Publish service management | Browser calls use `credentials: "include"`; backend proxies only allowed routes |

Source `/run/catlink/shell-env.sh` in user shells when present. It injects LightOS/Catlink environment expected by platform tooling inside the instance. For non-root users, resolve `uid/gid/home/shell`, set `HOME`, `USER`, `LOGNAME`, `SHELL`, `XDG_CONFIG_HOME`, optional `XDG_RUNTIME_DIR`, and prefer `setpriv` over `su` for the final login shell.

## Same-Page lightos-admin Return

The provider should let users return to lightos-admin without opening a new tab or guessing the admin domain.

Language-neutral algorithm:

1. Backend resolves admin info with `/lzcinit/lightosctl system admin-info --json`.
2. Frontend asks the provider backend for `base_url`; do not let browser code guess or hardcode the admin host.
3. Build a home URL from `base_url`, normally by setting `view=home` on the admin URL.
4. If admin info is unavailable, fall back only to a trusted cross-origin `document.referrer` normalized to its origin root.
5. Before navigating, persist active selector/tab/pane state and suppress intentional-navigation unload prompts.
6. Navigate in the same page with `location.assign(homeURL)`.

Do not use `window.open()` for normal return-home behavior. A WebShell provider is already launched from lightos-admin, so a new tab creates a split navigation stack and makes browser Back behavior unpredictable.

## Direct PTY Bridge

For a minimal provider, run a shell inside the target LightOS instance and bridge the PTY to the browser. The language-neutral algorithm is:

1. Validate the selector from `?name=<name>@<owner_deploy_id>`.
2. Start `/lzcinit/lightosctl exec -ti <selector> /bin/sh` with a terminal/PTY abstraction.
3. Source `/run/catlink/shell-env.sh` before launching the user's shell when the file exists.
4. Stream terminal bytes between the PTY and browser.
5. Apply terminal resize events to the PTY.
6. Kill or detach the child process cleanly when the browser disconnects.

For concrete full-code examples, see [examples.md](examples.md).

Terminal sizing:

- accept initial `cols` and `rows` from the WebSocket query string;
- default to a usable size such as `120x32`;
- handle `resize:<cols>,<rows>` messages and apply the equivalent PTY resize operation in the chosen runtime.

Use binary WebSocket messages for terminal bytes when practical. Text control messages such as `input:` and `resize:` are fine if the backend has an explicit protocol.

## Frontend Key Mapping

Keep a single explicit mapping from browser events to backend messages. Do not let the terminal renderer, mobile shortcut bar, and desktop shortcuts invent separate protocols.

Terminal byte path:

1. Terminal renderer emits bytes from normal keyboard input, paste, IME commit, or generated terminal responses.
2. Mobile shortcut buttons encode keys/modifiers into terminal bytes before sending:
   - Tab: `\t`
   - Shift+Tab: `\x1b[Z`
   - Return: `\r`
   - Esc: `\x1b`
   - Backspace: `\x7f`
   - Delete: `\x1b[3~`
   - arrows/home/end: CSI sequences such as `\x1b[A` or modified `\x1b[1;<modifier>A`
   - Ctrl letters: control bytes such as Ctrl+C `\x03`
   - Alt keys: ESC-prefixed bytes such as Alt+X `\x1bx`
3. Client queues bytes until history replay completes, then sends a control frame:

```json
{"type":"input","data":"...terminal bytes..."}
```

4. Backend writes `data` unchanged to the PTY/stdin unless input is locked.

Control path:

| Frontend event | Backend message/action |
| --- | --- |
| Terminal resize | stream control `{"type":"resize","cols":120,"rows":32}` |
| Input lock during reload | stream control `{"type":"input_lock","blocked":true}` |
| Intentional detach | stream control `{"type":"detach"}` |
| Ping/keepalive | stream control `{"type":"ping"}` and `{"type":"pong"}` |
| New/close/rename/move tab, split pane, select pane | workspace action endpoint, not terminal stdin |
| Copy/search/select-all/theme/instance switch | frontend-only UI action unless it changes workspace state |

Desktop shortcuts should map to named frontend actions first, for example `new_tab`, `vertical_split`, or `copy_terminal`. Only shortcuts that represent terminal input should become bytes. This prevents Ctrl+Shift+T from being accidentally sent to the shell when the user meant "new tab".

## UX Interaction Abstraction

Classify every interaction before wiring it:

| Interaction class | Examples | Owner | Transport |
| --- | --- | --- | --- |
| Terminal byte input | keyboard text, paste, IME commit, mobile Tab/Esc/arrows/Ctrl bytes | active pane | stream `input` frame |
| Stream control | resize, input lock, detach, ping/pong | active pane stream | stream control frame |
| Workspace action | new tab, split pane, close pane, rename, activate, move | session/workspace authority | `POST workspace action` |
| Frontend-only action | copy, search current buffer, theme picker, local menu, tab overview | browser UI | no backend call unless state changes |
| Platform navigation/API | return home, Catlink status, Publish service | LightOS/admin boundary | provider API or public admin endpoint |

This split keeps desktop shortcuts, mobile shortcut buttons, context menus, and terminal renderer events coherent. If two UI surfaces perform the same conceptual action, they must call the same action handler or emit the same protocol message.

## VT Parser and Renderer Boundary

For an interactive browser WebShell, VT parsing and rendering should normally live in the frontend. Use a browser terminal renderer such as xterm.js, Ghostty Web/WASM, hterm, or another proven VT renderer. The backend should stay a PTY/session broker:

- start or attach to the PTY/session;
- relay raw bytes without ANSI/CSI rewriting;
- apply resize and input-lock control messages;
- store bounded raw history for replay;
- expose workspace metadata such as tabs, panes, cwd, command, busy state, and server revision.

Do not implement a separate backend VT parser just because the backend language has a VT package. Two independent VT interpreters easily diverge on alternate screen, bracketed paste, mouse tracking, OSC sequences, wide glyphs, emoji, CJK width, and application cursor modes.

Use backend headless VT only when there is a concrete server-side need:

| Need | Recommendation |
| --- | --- |
| Browser display | Frontend VT renderer. |
| Refresh/reconnect history | Store raw output and replay to the frontend renderer. |
| Search/copy current buffer | Prefer frontend renderer APIs; use backend VT only if search must work while no client is attached. |
| Collaboration/shared snapshots | Pick one backend headless VT as source of truth and treat the frontend as a renderer of snapshots plus live deltas. |
| Existing web terminal adapter | Let the adapted web terminal own its VT/rendering; provider only forwards/proxies. |

If a backend VT is required, make it an explicit architecture decision, choose one library for the whole provider, document unsupported escape sequences, and test it against the frontend renderer with recorded byte streams.

## Persistent Sessions

Provider process restarts should not destroy user work. Prefer keeping session state inside the target LightOS instance:

- an instance-local session manager or agent;
- tmux/zellij only when the chosen product architecture explicitly wraps those tools;
- instance-local shell history and working directory state for simpler providers.

The provider LPK backend should mainly serve UI, discover sessions, attach to existing sessions, and proxy traffic.

Minimum restore contract:

| Endpoint/Message | Purpose |
| --- | --- |
| `GET workspace state` | Return selector, server revision, active tab, tab order, layouts, panes, cwd/command metadata. |
| `POST workspace action` | Apply create/close/rename/move/split/activate actions and return the updated state. |
| `GET workspace activity` | Refresh busy flags, command names, cwd, and exited panes without rebuilding UI. |
| `ATTACH stream` | Attach to a stable pane ID and stream terminal I/O. |

Client restore rules:

- restore tabs and panes from state before opening streams;
- keep `tab_id` in the URL when possible and remember the last tab per selector in local storage;
- keep a short-lived restart tab in session storage before intentional reloads;
- reconnect visible panes on `online`, `focus`, and `visibilitychange`;
- queue user input until history replay is complete, with a hard size limit.

History replay rules:

- send a `history-replay-start` control frame before buffered output;
- include selector and pane ID in replay control frames;
- send replayed output as terminal bytes, chunked to bounded sizes;
- send `history-replay-complete` before accepting queued user input;
- close and refetch state if replay identity does not match the requested selector/pane.

Server/runtime revision rules:

- expose a monotonic content/runtime revision to the client;
- when a revision change requires reload, lock terminal input before prompting;
- preserve the active selector and tab before reload;
- clear the input lock once the refreshed client reconnects.

Multi-device note: one PTY normally has one active cols/rows size. If multiple clients attach to the same pane, resize to the actively interacting device and document that passive viewers may see terminal wrapping change.

### Source-Proven Instance Agent Pattern

The `lazycat-microserver-webshell` reference uses this algorithm; port the algorithm, not the Go implementation:

1. The provider resolves selector/account and ensures an instance-local agent is installed.
2. The agent listens on an instance-local private socket scoped by selector/account.
3. The provider sends JSON requests for `state`, `action`, and `activity`.
4. The provider starts an `attach` bridge with `lightosctl exec -i <selector> <agent-bin> agent attach ...`.
5. The agent attaches the bridge to a stable `pane_id` and streams framed bytes/control messages.
6. The browser rebuilds workspace state first, then opens streams for visible panes.

This puts durable tab/pane/process state near the PTYs. The provider can restart without killing instance-local sessions if the agent protocol remains compatible.

### Multi-Client Output Consistency

When the same pane is open from multiple tabs/devices, consistency comes from one output source and replay identity:

| Step | Required behavior |
| --- | --- |
| PTY output | Read raw PTY bytes once. Filter only provider-private control responses or generated echo noise; do not reinterpret terminal output in the backend. |
| History | Append output chunks to bounded per-pane raw history before broadcasting. Trim by bytes/scrollback policy, not by client count. |
| Broadcast | Send the same output chunks to every attached client for that pane. Slow clients need queue limits and disconnect/backpressure policy. |
| Attach | New clients receive `history-replay-start` with selector + pane ID, then history bytes, then `history-replay-complete`. |
| Client validation | Client rejects replay if selector/pane identity does not match the requested stream. |
| Input timing | Client queues input until replay completes; backend ignores input while input lock is active. |
| Generated responses | Only the intended attach should answer terminal-generated queries during replay; secondary clients suppress generated cursor/device-status responses. |
| Resize | The last active client can resize the PTY; passive clients may see wrapping change. For collaborative editing, define a leader/follower resize policy. |
| Exit | Process-exit is a control event; notify all clients, close the pane, then refresh workspace state. |

Do not create a separate PTY per browser tab if the user expects shared panes. That gives each device a different process and makes output consistency impossible.

## Mobile Terminal UX

A mobile WebShell must be designed as a touch terminal, not a shrunken desktop terminal.

Required behavior:

- use `<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">`;
- account for safe-area insets on top/bottom/left/right;
- avoid fixed `100vh` for the terminal body; use `100dvh` or a visual viewport variable updated on keyboard/orientation changes;
- provide touch shortcuts for Tab, Return, arrows, Esc, Ctrl/Alt/Shift, copy/paste/search, split, tab switching, and menu actions;
- make all actions reachable without hover, right click, or a hardware keyboard;
- handle CJK IME composition with a separate preview or equivalent state so intermediate composition text is not sent repeatedly to the terminal;
- handle mobile selection with long press, draggable handles, and a touch-friendly action sheet;
- intercept mobile browser Back only for in-app overlays such as tab overview; never trap users on the page permanently;
- remeasure and send terminal cols/rows after keyboard open/close, orientation change, visibility changes, and focus return.
- show connection state and retryable errors without stealing focus from the terminal;
- use health ping/resume probes and reconnect visible panes on `online`, focus, visibility, and page-show.

Recommended options:

- pixel-level scroll for mobile when the terminal renderer supports it;
- haptic/touch feedback toggle for shortcut keys;
- compact tab overview with previews for multiple sessions;
- a mobile close confirmation when panes or tabs have running commands.

## Forwarding Existing Web Terminals

Use `lightosctl forward` when adapting an existing web terminal or session manager inside the target instance:

```sh
/lzcinit/lightosctl forward -L 127.0.0.1:19082:127.0.0.1:39082 '<name>@<owner_deploy_id>'
```

`forward` requires LZCOS v1.5.3 or newer. It binds a provider-local port and forwards to the target instance. The provider can then reverse proxy browser traffic to `127.0.0.1:<local-port>`.

Lifecycle rules:

- start forwarding only when needed;
- tie forward processes to the selected instance;
- stop stale processes when the provider exits or the instance changes;
- treat instance stop/disappear as a normal forward termination case.

## Catlink

Inside instance shells, source Catlink environment when present:

```sh
if [ -f /run/catlink/shell-env.sh ]; then
  . /run/catlink/shell-env.sh
fi
```

For tmux/zellij, ensure new panes inherit the same environment.

The provider frontend should ask its own backend for lightos-admin info. The backend resolves it with:

```sh
/lzcinit/lightosctl system admin-info --json
```

Then the frontend can create the hidden attach frame:

```text
<admin-base>/api/webshell/catlink/provider-frame?name=<selector>
```

Status endpoint:

```http
GET <admin-base>/unsafe_api/webshell/catlink/provider-status?name=<selector>
```

Use `credentials: "include"` for browser requests to lightos-admin.

## Publish API

Use Publish API to expose HTTP services running inside a LightOS instance. It creates or updates Shell LPK services.

Status:

```http
GET <admin-base>/unsafe_api/publish/status
```

List:

```http
GET <admin-base>/unsafe_api/publish/services
```

Create or update:

```http
POST <admin-base>/unsafe_api/publish/services
Content-Type: multipart/form-data
```

Required form fields:

| Field | Meaning |
| --- | --- |
| `instance_name` | Full selector, for example `demo@cloud.lazycat.lightos.entry`. |
| `upstream` | HTTP URL reachable from inside the target instance. |
| `package_id` | Stable package ID; reusing it updates the existing service. |
| `app_url` | Full URL the user should open after creation. |
| `title` | Display title. |
| `skip_auth` | Explicit boolean; only set true when public access is intended. |
| `icon` | Optional PNG file. |

Delete:

```http
DELETE <admin-base>/unsafe_api/publish/services/<id>
```

## Common Failures

| Symptom | Check |
| --- | --- |
| Provider not listed | `resource_exports` has `kind: lightos.webshell`; source path exists; `webshell-provider.json` is under `resources/lightos.webshell/default/`. |
| Instance list or shell fails | `package.yml` includes `lightos.manage`; backend runs inside LazyCat environment; `/lzcinit/lightosctl ps` works. |
| Provider opens but assets or WS fail | `root_path`, `application.routes`, frontend relative paths, and WebSocket URL prefix match. |
| Selector not found | URL contains `?name=<name>@<owner_deploy_id>`; backend does not split away `owner_deploy_id`. |
| Cross-account instance access | Every state/action/attach/forward/publish path authorizes selector ownership before work starts. |
| Return to admin opens extra tabs | Resolve `admin-info.base_url`, persist provider state, then use same-page `location.assign(<base>?view=home)`. |
| Refresh loses tabs/panes | Workspace state lacks stable tab/pane IDs or restore happens after stream attach. |
| Reconnect duplicates or scrambles output | History replay lacks start/complete markers or selector/pane identity validation. |
| Two browser tabs show different output for the same pane | Provider created separate PTYs or per-client histories; use one pane history plus broadcast and replay. |
| Input lands before replay finishes | Client must queue input until `history-replay-complete`; backend should honor `input_lock`. |
| Passive viewer sees line wrapping change | Shared PTY was resized by another device; document this or implement leader/follower resize policy. |
| Resize is broken | Frontend sends terminal cols/rows on connect and resize; backend validates positive integers before `pty.Setsize`. |
| Mobile keyboard covers terminal | Use visual viewport/safe-area sizing and remeasure terminal after keyboard transitions. |
| IME duplicates characters | Keep composition state separate and send text only after committed input. |
| Catlink status fails | Backend returns valid `admin-info`; frontend uses `/unsafe_api/webshell/catlink/provider-status` with `credentials: "include"`. |
| Publish requests fail | Use only `/unsafe_api/publish/*`; include credentials; send multipart form data; provide stable `package_id` and full `app_url`. |

## Source Examples

See [examples.md](examples.md) for full copied source trees:

- [examples/demo-webshell](examples/demo-webshell): minimal PTY bridge, instance list, Catlink bridge, Publish API demo.
- [examples/zellij-webshell](examples/zellij-webshell): wraps zellij Web UI through instance-local setup and `lightosctl forward`.
- [examples/lazycat-microserver-webshell](examples/lazycat-microserver-webshell): Ghostty Web based microserver WebShell provider.
