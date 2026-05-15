# Complete Examples

The examples below are copied as full source/resource trees so agents can reuse complete code instead of reconstructing from snippets. They are implementation examples, not protocol requirements; the provider contract remains language-neutral in [provider-contract.md](provider-contract.md).

## Example Matrix

| Example | Use When | Key Traits |
| --- | --- | --- |
| [examples/demo-webshell](examples/demo-webshell) | Building or explaining the smallest provider. | Direct PTY bridge, xterm.js UI, instance list, Catlink attach/status, Publish API smoke UI. |
| [examples/zellij-webshell](examples/zellij-webshell) | Wrapping a persistent terminal/session manager. | Installs or reuses zellij inside the target instance, runs zellij Web, uses `lightosctl forward`, reverse proxies browser traffic. |
| [examples/lazycat-microserver-webshell](examples/lazycat-microserver-webshell) | Building a Ghostty Web based provider for LazyCat Microserver. | Uses Ghostty Web static runtime, Go backend, `lightosctl exec`, and full LPK provider metadata. |

## Included Files

`demo-webshell` includes:

- `package.yml`, `lzc-build.yml`, `lzc-manifest.yml`;
- `resources/lightos.webshell/default/webshell-provider.json`;
- `go.mod`, `go.sum`, complete `main.go`;
- `runtime/static/index.html`, `main.js`, `style.css`, `lightos-catlink-provider.js`;
- xterm runtime assets loaded from CDN (jsDelivr) in the example code.

`zellij-webshell` includes:

- `README.md`, `package.yml`, `lzc-build.yml`, `lzc-manifest.yml`;
- `resources/lightos.webshell/default/webshell-provider.json`;
- `go.mod`, complete `main.go`;
- `config.kdl.tpl` for the instance-local zellij configuration.

`lazycat-microserver-webshell` includes:

- `README.md`, `package.yml`, `lzc-build.yml`, `lzc-manifest.yml`;
- `resources/lightos.webshell/default/webshell-provider.json`;
- `go.mod`, `go.sum`, complete `main.go`;
- `runtime/static/index.html`, `main.js`, `style.css`;
- Ghostty Web runtime assets required by the copied example; provide via your own build or npm package.

## 依赖与离线部署

**示例中的 vendor 文件使用在线 CDN 资源，仅用于简化 demo 代码。生产环境下，LPK 应用应使用全离线资源：**

- `demo-webshell`: xterm.js / xterm-addon-fit 通过 jsDelivr CDN 加载。生产部署时需将 xterm.min.js、xterm.min.css 打包进 LPK contentdir。
- `lazycat-microserver-webshell`: ghostty-web.js / ghostty-vt.wasm 需通过自行构建或 npm 包提供，同样打包进 contentdir。
- `zellij-webshell`: 不依赖前端 vendor 库，后端直接反向代理 zellij Web UI。

LazyCat 环境默认不保证外网可达，依赖 CDN 的 LPK 在离线环境中将无法正常工作。

## Use Guidance

Start from `demo-webshell` when implementing a provider from scratch. Move to `zellij-webshell` when user requirements include persistent panes/tabs or an existing terminal manager. Use `lazycat-microserver-webshell` when the desired UX or runtime is closer to Ghostty Web.

When adapting any example:

- preserve the `lightos.webshell` resource export location and `webshell-provider.json` shape;
- keep the entry URL selector contract as `?name=<name>@<owner_deploy_id>`;
- keep the provider language/runtime replaceable unless the user explicitly chooses Go;
- run the example's normal language checks, then `lzc-cli project release`;
- verify discovery and launch inside lightos-admin after installing the LPK.
