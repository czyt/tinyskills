# 自动拦截文件选择器 (File Picker Auto-Intercept)

## 概述

通过 `injects` 机制，在不修改上游源码的情况下，拦截应用里的原生文件入口，提供"网盘文件 / 本地文件"两种选择。

**⚠️ 应用商店强制要求**：有上传/下载功能的应用必须接入此拦截器，否则无法上架。官方文档：https://developer.lazycat.cloud/lazycat-file-picker-auto-intercept

---

## 前置条件

1. lzcos 版本支持 `browser`、`request` inject 和 `ctx.proxy`。
2. 已阅读 [injects.md](injects.md)（脚本注入）与官方 manifest inject 规范。
3. 已掌握部署参数渲染。

---

## 覆盖范围（2026-10 版）

拦截后显示带"网盘文件 / 本地文件"选项的统一窗口。网盘选择器显示在窗口内；选择本地文件时继续应用原有的浏览器流程。

| 操作 | 覆盖的原生 API |
|------|---------------|
| 打开 | `showOpenFilePicker()`、普通 `<input type="file">`；从网盘打开的文件句柄支持后续写回 |
| 保存 | `showSaveFilePicker()`、带 `download` 属性的 `blob:` / `data:` 链接（`saveAs` 模式，`saveNames` 显示建议文件名） |
| 进度 | 保存到网盘时显示上传进度 |
| 冲突 | 新建文件收到 WebDAV `412 Precondition Failed` → 追加序号重试；`409 Conflict` → 直接报错（不误判为同名） |

**当前只处理网盘的 `/files/home` 空间。** 目录选择、浏览器接管的普通 HTTP 下载、应用直接发起的 `fetch` / `PUT` 不经过这些文件入口，需单独接入。

---

## 适用场景

**适合**：
- 已支持浏览器原生文件能力，但还没接懒猫网盘
- 不想改上游源码，只想通过注入把文件流转接过来
- 应用里存在"打开、保存、上传、下载"这些文件入口

**不适合**：
- 应用根本没有文件打开/保存入口
- 愿意直接改业务前端源码（可自己接库，走 `<lzc-file-picker>` 组件）

---

## 配置步骤

### 1. 准备脚本文件

将 `lzc-file-chooser-inject.js` 放入包的 content 目录：

```
content/
└── lazycat-injects/
    └── lzc-file-chooser-inject.js
```

**下载地址**：`https://developer.lazycat.cloud/lazycat-injects/lzc-file-chooser-inject.js`

### 2. 配置 lzc-manifest.yml（两段式：browser inject + request inject）

**⚠️ 关键：必须同时配置两段。** 只复制 browser inject 时，自己的目录可能仍能通过 `diskRoot` 工作，但他人共享目录无法按 `owner` 切换到正确的文件根目录。

```yaml
application:
  subdomain: myapp
  routes:
    - /=file:///lzcapp/pkg/content/dist
  injects:
    # ① browser inject：接管页面文件入口
    - id: open-save-chooser
      on: browser
      when:
        - /*
      do:
        - src: file:///lzcapp/pkg/content/lazycat-injects/lzc-file-chooser-inject.js
          params:
            fileBridgeRoot: /__lazycat_file_bridge   # 必须和下面 bridgePrefix 一致
    # ② request inject：同源文件桥接（共享目录 owner 转发）
    - id: lazycat-file-bridge
      on: request
      when:
        - /__lazycat_file_bridge/*
      do:
        - src: |
            const bridgePrefix = "/__lazycat_file_bridge";
            const requestHost = String(ctx.request.host || "")
              .split(":")[0]
              .toLowerCase();
            const firstDot = requestHost.indexOf(".");
            const method = String(ctx.request.method || "").toUpperCase();

            if (
              firstDot <= 0 ||
              !requestHost.endsWith(".heiyu.space") ||
              !["GET", "HEAD", "PUT"].includes(method)
            ) {
              ctx.response.send(
                ["GET", "HEAD", "PUT"].includes(method) ? 400 : 405,
                "Invalid LazyCat file bridge request",
              );
              return;
            }

            const boxDomain = requestHost.slice(firstDot + 1);
            const fileOrigin = "https://file." + boxDomain;
            const targetPath =
              "/files/home" + ctx.request.path.slice(bridgePrefix.length);
            # ……（转发到 fileOrigin，ctx.proxy 见官方完整示例）
```

**为什么需要 request inject？** 选择器返回的 `webdavUrl` 位于 `file.<微服域名>.heiyu.space`，应用页面在另一个子域名——直接从页面向该地址发送带 `Owner` 的 WebDAV 请求会被浏览器跨域规则限制。`lazycat-file-bridge` 在应用域名下接收同源请求，再通过 `ctx.proxy` 转发到当前微服的网盘服务；共享目录的读写携带选择器返回的 `owner`，能否保存由共享目录写入权限决定。

完整 request inject 源码以官方文档为准（本文只保留骨架，复制全文请取官方页）。

### 3. 自定义参数（可选）

```yaml
injects:
  - id: open-save-chooser
    on: browser
    when:
      - /*
    do:
      - src: file:///lzcapp/pkg/content/lazycat-injects/lzc-file-chooser-inject.js
        params:
          diskRoot: /_lzc/files/home
          fileBridgeRoot: /__lazycat_file_bridge
          fallbackMime: application/octet-stream
          locale: auto
          hooks:
            fileSystemAccess: true
            fileInput: true
            downloadAnchor: true
```

---

## 参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `diskRoot` | `string` | `/_lzc/files/home` | 懒猫网盘在当前站点下的文件根路径 |
| `fileBridgeRoot` | `string` | `/__lazycat_file_bridge` | 选择器返回 `/files/home` 地址时使用的同源桥接路径，必须和 request inject 的 `bridgePrefix` 一致 |
| `fallbackMime` | `string` | `application/octet-stream` | 无法判断文件类型时的兜底 MIME |
| `locale` | `string` | `auto` | 文案语言，`auto` 按浏览器语言自动选择 |
| `text` | `object` | `{}` | 自定义按钮和标题文案，支持按语言分组 |
| `hooks.fileSystemAccess` | `bool` | `true` | 是否接管 `showOpenFilePicker()` / `showSaveFilePicker()` |
| `hooks.fileInput` | `bool` | `true` | 是否接管 `<input type="file">` |
| `hooks.downloadAnchor` | `bool` | `true` | 是否接管带 `download` 属性的 `blob:` / `data:` 链接 |

### text 参数详细字段

| 字段 | 默认中文 | 默认英文 | 显示位置 |
|------|---------|---------|---------|
| `openTitle` | 打开 | Open | 打开窗口的无障碍标题 |
| `saveTitle` | 保存 | Save | 保存窗口的无障碍标题 |
| `cloudTab` | 网盘文件 | Cloud files | 顶部网盘选项 |
| `localTab` | 本地文件 | Local files | 顶部本地选项 |
| `openLazyCat` | 从懒猫打开 | Open from LazyCat | 网盘打开选择器标题 |
| `saveLazyCat` | 保存至懒猫 | Save to LazyCat | 网盘保存选择器标题 |

### text 参数规则

1. `locale: auto` 时，浏览器语言以 `zh` 开头就使用 `zh-CN`，否则使用 `en-US`
2. 未配置 `text` 时使用内置默认文案
3. 只配置部分字段时，未配置的字段继续使用当前语言的默认文案
4. 同时写了语言分组和顶层字段时，顶层字段优先级更高

### 文件名管理

文件名由 `<lzc-file-picker type="saveAs">` 的 `saveNames` 和选择结果统一管理，外层窗口不再创建第二个文件名输入框。

---

## file_handler 配置

`file_handler` 用于声明应用支持的文件类型和打开方式：

```yaml
application:
  file_handler:
    mime:
      - x-lzc-extension/myapp
      - application/json
    actions:
      open: /?fileUrl=/%u
```

- `mime`：支持的 MIME 类型列表
- `actions.open`：打开文件时的路由路径，`%u` 会被替换为文件 URL

---

## 验证方法

1. 打开应用页面，触发一次"打开文件"或"保存文件"
2. 页面出现"网盘文件 / 本地文件"的选择窗口
3. 选择"网盘文件"，会打开懒猫文件选择器
4. 选择"本地文件"后，应用原有流程继续执行
5. 选择一个他人共享且可写的目录保存文件，确认请求地址以 `/__lazycat_file_bridge/` 开头，并且请求头包含选择器返回的 `Owner`

---

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 弹窗不出现 | inject 未命中路径 | 检查 `when` 条件是否覆盖文件操作页面 |
| 选择懒猫后无反应 | `diskRoot` 路径不正确 | 确认 `/_lzc/files/home` 可访问 |
| 保存到他人共享目录返回 `409 Conflict` | 请求仍发往 `/_lzc/files/home/`，说明只更新了 browser inject | 检查请求地址应为 `/__lazycat_file_bridge/` 开头；补齐 `lazycat-file-bridge` request inject 或改用最新脚本。`409` 只表示路径或父目录冲突，不能据此判断文件同名——脚本只把带 `If-None-Match: *` 的 `412` 当作同名冲突 |
| 双重弹窗 | 原生和拦截同时触发 | 确认 `hooks` 配置正确，脚本只加载一次 |
| 中文页面显示英文 | `locale` 未设为 `auto` | 设置 `locale: auto` 或手动配置 `text.zh-CN` |

---

**参考文档**：
- [injects.md](injects.md) - 脚本注入完整参考
- [store-rule.md](store-rule.md) - 应用商店审核规则
- 官方文档：https://developer.lazycat.cloud/lazycat-file-picker-auto-intercept

**最后更新**: 2026-10（同步上游 file-picker 指南更新：两段式 bridge、`fileBridgeRoot`、`downloadAnchor`、412/409 语义）
