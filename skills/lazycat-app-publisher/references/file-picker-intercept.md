# 自动拦截文件选择器 (File Picker Auto-Intercept)

## 概述

通过 `injects` 机制，在不修改上游源码的情况下，拦截应用里的原生文件入口，并提供"本地文件系统 / 懒猫微服"两种选择。

**⚠️ 应用商店强制要求**：有上传/下载功能的应用必须接入此拦截器，否则无法上架。

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

## 拦截的能力

脚本拦截三类文件操作：

| 操作 | 原生 API | 拦截方式 |
|------|---------|---------|
| 打开文件 | `showOpenFilePicker()` | File System Access API hook |
| 保存文件 | `showSaveFilePicker()` | File System Access API hook |
| 上传文件 | `<input type="file">` | HTMLInputElement.click hook |
| 下载文件 | `<a download>` | HTMLAnchorElement.click hook |

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

### 2. 配置 lzc-manifest.yml

```yaml
application:
  subdomain: myapp
  routes:
    - /=file:///lzcapp/pkg/content/dist
  injects:
    - id: open-save-chooser
      on: browser
      when:
        - /*
      do:
        - src: file:///lzcapp/pkg/content/lazycat-injects/lzc-file-chooser-inject.js
  file_handler:
    mime:
      - x-lzc-extension/myapp
    actions:
      open: /?fileUrl=/%u
```

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
          fallbackMime: application/octet-stream
          locale: auto
          text:
            zh-CN:
              openTitle: 打开
              saveTitle: 保存
              openLocal: 从本地打开
              openLazyCat: 从懒猫打开
              saveLocal: 保存至本地
              saveLazyCat: 保存至懒猫
              cancel: 取消
            en-US:
              openTitle: Open
              saveTitle: Save
              openLocal: Open from local device
              openLazyCat: Open from LazyCat
              saveLocal: Save to local device
              saveLazyCat: Save to LazyCat
              cancel: Cancel
          hooks:
            fileSystemAccess: true
            fileInput: true
```

---

## 参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `diskRoot` | `string` | `/_lzc/files/home` | 懒猫网盘在当前站点下的文件根路径 |
| `fallbackMime` | `string` | `application/octet-stream` | 无法判断文件类型时的兜底 MIME |
| `locale` | `string` | `auto` | 文案语言，`auto` 按浏览器语言自动选择 |
| `text` | `object` | `{}` | 自定义按钮和标题文案，支持按语言分组 |
| `hooks.fileSystemAccess` | `bool` | `true` | 是否接管 `showOpenFilePicker()` / `showSaveFilePicker()` |
| `hooks.fileInput` | `bool` | `true` | 是否接管 `<input type="file">` |

### text 参数详细字段

| 字段 | 默认中文 | 默认英文 | 显示位置 |
|------|---------|---------|---------|
| `openTitle` | 打开 | Open | 打开文件弹窗标题 |
| `saveTitle` | 保存 | Save | 保存文件弹窗标题 |
| `openLocal` | 从本地打开 | Open from local device | 打开文件时的本地选项 |
| `openLazyCat` | 从懒猫打开 | Open from LazyCat | 打开文件时的懒猫选项 |
| `saveLocal` | 保存至本地 | Save to local device | 保存文件时的本地选项 |
| `saveLazyCat` | 保存至懒猫 | Save to LazyCat | 保存文件时的懒猫选项 |
| `cancel` | 取消 | Cancel | 弹窗取消按钮 |

### text 参数规则

1. `locale: auto` 时，浏览器语言以 `zh` 开头就使用 `zh-CN`，否则使用 `en-US`
2. 未配置 `text` 时使用内置默认文案
3. 只配置部分字段时，未配置的字段继续使用当前语言的默认文案
4. 同时写了语言分组和顶层字段时，顶层字段优先级更高

---

## file_handler 配置

`file_handler` 用于声明应用支持的文件类型和打开方式：

```yaml
application:
  file_handler:
    mime:
      - x-lzc-extension/excalidraw
      - application/json
    actions:
      open: /?fileUrl=/%u
```

- `mime`：支持的 MIME 类型列表
- `actions.open`：打开文件时的路由路径，`%u` 会被替换为文件 URL

---

## 验证方法

1. 打开应用页面，触发一次"打开文件"或"保存文件"
2. 页面出现"本地文件系统 / 懒猫微服"的选择弹窗
3. 选择"懒猫微服"，会打开懒猫文件选择器
4. 选择"本地文件系统"后，应用原有流程继续执行

---

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 弹窗不出现 | inject 未命中路径 | 检查 `when` 条件是否覆盖文件操作页面 |
| 选择懒猫后无反应 | `diskRoot` 路径不正确 | 确认 `/_lzc/files/home` 可访问 |
| 双重弹窗 | 原生和拦截同时触发 | 确认 `hooks` 配置正确，脚本只加载一次 |
| 中文页面显示英文 | `locale` 未设为 `auto` | 设置 `locale: auto` 或手动配置 `text.zh-CN` |

---

**参考文档**：
- [injects.md](injects.md) - 脚本注入完整参考
- [store-rule.md](https://developer.lazycat.cloud/store-rule) - 应用商店审核规则
- 官方文档：https://developer.lazycat.cloud/lazycat-file-picker-auto-intercept

**最后更新**: 2026-06-04
