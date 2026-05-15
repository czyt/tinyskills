# Zellij WebShell Example

这个示例展示如何把现有 Web terminal/session manager 包装成 WebShell provider。它使用 zellij 的 Web UI，并通过 provider 后端代理目标 LightOS 实例内的 zellij Web 服务。

打开 `/?name=<name>@<owner_deploy_id>` 时，provider 后端会读取 selector，并在对应 LightOS 实例内安装 zellij 二进制、写入 zellij 配置、启动或复用 zellij session 和 zellij web server。随后 provider 通过 `/lzcinit/lightosctl forward -L ...` 把实例内 zellij web server 转发到 provider 本地端口，再反向代理给浏览器。

`lightosctl forward` 依赖 LZCOS v1.5.3 或更新版本。

## 构建

构建前需要准备 Linux amd64 可执行的 `zellij` 二进制。脚本会优先使用 `ZELLIJ_BIN`，未设置时从 `PATH` 查找 `zellij`。

```sh
ZELLIJ_BIN="$(command -v zellij)" lzc-cli project release
```

生成的 LPK 位于 `dist/`。

## 示例边界

这个示例不是最小 WebShell provider 模板。它包含 zellij Web UI 的专属适配：

- 自动登录通过重写 zellij Web 前端资源实现。
- 代理路径和 cookie 处理只服务于 zellij Web UI。
- zellij session、socket、配置和 web server 都维护在目标 LightOS 实例内。
- provider LPK 自身只负责准备实例内 runtime、维护实例内 zellij Web 服务转发和代理 zellij Web UI。

稳定的 provider 对接契约以根目录 [WebShell Provider 开发说明](../../webshell_provider.md) 为准。学习 provider 声明、实例 selector、`lightosctl exec`、Catlink 和 Publish API 时，优先阅读 `examples/demo-webshell`。
