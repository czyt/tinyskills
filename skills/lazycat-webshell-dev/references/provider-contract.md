# LazyCat WebShell Provider Contract

This reference distills the `webshell-provider-examples` repo into reusable implementation rules for LazyCat/LightOS WebShell providers.

## Stable Contract

WebShell providers are normal LPK apps. The protocol is language-neutral: any backend runtime can implement it if it can serve HTTP, handle WebSocket or streaming transport, run `lightosctl`, parse JSON, and manage processes or PTYs when terminal bridging is needed.

lightos-admin discovers installed providers through `resource_exports`, then opens the provider entry URL with a LightOS instance selector:

```text
https://<provider-domain><root_path>?name=<name>@<owner_deploy_id>
```

The provider must not depend on lightos-admin source code, private routes, or internal frontend state. The public contract is the provider app URL plus the `name` query parameter.

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
| `support_home` | Third-party providers normally use `false`; lightos-admin opens the provider in a new page. |
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
hidden_from_launcher: true
permissions:
  required:
    - lightos.manage
locales:
  zh:
    name: 示例 WebShell
    description: LightOS WebShell provider 示例
```

Use `hidden_from_launcher: true` when the app only makes sense when launched from lightos-admin for a selected instance.

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

## Persistent Sessions

Provider process restarts should not destroy user work. Prefer keeping session state inside the target LightOS instance:

- tmux or zellij sessions;
- an instance-local session manager;
- instance-local shell history and working directory state.

The provider LPK backend should mainly serve UI, discover sessions, attach to existing sessions, and proxy traffic.

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
| Resize is broken | Frontend sends terminal cols/rows on connect and resize; backend validates positive integers before `pty.Setsize`. |
| Catlink status fails | Backend returns valid `admin-info`; frontend uses `/unsafe_api/webshell/catlink/provider-status` with `credentials: "include"`. |
| Publish requests fail | Use only `/unsafe_api/publish/*`; include credentials; send multipart form data; provide stable `package_id` and full `app_url`. |

## Source Examples

See [examples.md](examples.md) for full copied source trees:

- [examples/demo-webshell](examples/demo-webshell): minimal PTY bridge, instance list, Catlink bridge, Publish API demo.
- [examples/zellij-webshell](examples/zellij-webshell): wraps zellij Web UI through instance-local setup and `lightosctl forward`.
- [examples/lazycat-microserver-webshell](examples/lazycat-microserver-webshell): Ghostty Web based microserver WebShell provider.
