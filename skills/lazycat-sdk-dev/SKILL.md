---
name: lazycat-sdk-dev
description: LazyCat SDK 开发技能，用于 Go/JS 应用与微服务 API 交互（用户、设备、应用、设备控制）。包含前端 WebShell 能力（AppCommon、MediaSession、主题、导航）和系统通知推送（notification.Notify）。触发词：@lazycatcloud/sdk 导入、lzc-sdk 引用、SDK/WebShell/设备查询/通知推送/user.notify。
---

# LazyCat SDK 开发

协助开发者使用官方 SDK 与 LazyCat 微服务系统交互。

## 支持语言

| 语言 | 包名 | 导入路径 |
|------|------|---------|
| **Go** | `gitee.com/linakesi/lzc-sdk` | `gitee.com/linakesi/lzc-sdk/lang/go` |
| **JavaScript/TypeScript** | `@lazycatcloud/sdk` | npm 包 |

即将支持：Rust、Dart、Cpp、Java、Python、Ruby、C#、PHP、Objective-C、Kotlin。

## 参考文档

| 文档 | 内容 |
|------|------|
| [references/frontend-extensions.md](references/frontend-extensions.md) | **前端客户端能力** - iOS/Android WebShell 能力矩阵，AppCommon API，导航栏/状态栏 meta，MediaSession 等 |
| [references/go-sdk.md](references/go-sdk.md) | **Go SDK 完整参考** - API Gateway，User/Device/Box/App 管理，HTTP handlers |
| [references/js-sdk.md](references/js-sdk.md) | **JavaScript/TypeScript SDK 参考** - 基础用法，API 操作，前端集成 |
| [references/extensions.md](references/extensions.md) | **扩展模块** - minidb，file-pickers，跨应用通信 |

---

## 开发工作流

### Phase 1: 环境初始化

**输入**: 开发环境已准备（Go/Node.js）
**输出**: SDK 已安装，可调用 API Gateway

#### Step 1.1: 安装 SDK

```bash
# Go 项目
go get gitee.com/linakesi/lzc-sdk/lang/go

# JavaScript/TypeScript 项目
npm install @lazycatcloud/sdk
```

#### Step 1.2: 创建 API Gateway

**Go**:
```go
gw, err := gohelper.NewAPIGateway(ctx)
if err != nil {
    return err  // ⚠️ 检查点：创建失败时返回错误，不要继续
}
defer gw.Close()  // ✅ 必须关闭！
```

**JavaScript**:
```js
const api = new lzcAPIGateway(window.location.origin, false)
```

### Phase 2: 业务开发

**输入**: API Gateway 已创建
**输出**: 完成用户/设备/应用管理等功能

#### Step 2.1: 确定需求类型

| 需求 | 服务 | 参考章节 |
|------|------|---------|
| 用户信息查询 | `gw.Users` | [go-sdk.md#Users](references/go-sdk.md) |
| 设备列表/状态 | `gw.Devices` | [go-sdk.md#Devices](references/go-sdk.md) |
| 设备控制(LED/重启) | `gw.Box` | [go-sdk.md#Box](references/go-sdk.md) |
| 应用管理 | `gw.PkgManager` | [go-sdk.md#PkgManager](references/go-sdk.md) |
| 前端客户端能力 | `AppCommon` | [frontend-extensions.md](references/frontend-extensions.md) |
| 系统通知推送 | `notification.Notify` | [frontend-extensions.md#通知](references/frontend-extensions.md) |

#### Step 2.2: 添加用户上下文（HTTP Handler 必须）

**⚠️ 检查点**: 如果是 HTTP Handler，必须传递用户上下文

**可用 Headers**:

| Header | 格式 | 来源 |
|--------|------|------|
| `x-hc-user-id` | 字符串 (如 `lazycat`) | HTTP Header |
| `x-hc-user-role` | `admin` 或 `user` | HTTP Header |
| `x-hc-device-id` | 字符串 | HTTP Header |
| `x-hc-device-version` | 版本号 (如 `1.5.0`) | HTTP Header |

**示例**:
```go
// Gin 框架示例
userID := c.GetHeader("x-hc-user-id")        // 必须是小写
userRole := c.GetHeader("x-hc-user-role")

// 添加到 gRPC context (metadata key 必须小写)
ctx = metadata.AppendToOutgoingContext(ctx,
    "x-hc-user-id", userID,
    "x-hc-user-role", userRole,
)
```

#### Step 2.3: 编写业务代码

参考 [常用示例](#常用示例) 或具体参考文档。

### Phase 3: 错误处理与测试

**输入**: 业务代码完成
**输出**: 稳定运行，错误有 fallback

#### Step 3.1: 添加超时控制

**推荐超时值**:

| 操作类型 | 推荐超时 | 原因 |
|---------|---------|------|
| 设备列表查询 | 10s | 网络可能慢 |
| 用户信息查询 | 5s | 快速操作 |
| 应用状态变更 | 30s | 涉及容器操作 |
| 设备控制(LED/重启) | 15s | 需要硬件响应 |

**示例**:
```go
// 查询类操作
ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
defer cancel()

// 状态变更类操作
ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
defer cancel()
```

#### Step 3.2: 处理 SDK 错误

```go
result, err := gw.Service.Method(ctx, &Request{...})
if err != nil {
    // ⚠️ 检查点：记录日志，返回 fallback 响应
    log.Printf("SDK call failed: %v", err)
    return fallbackValue
}
```

---

## 快速开始

### Go SDK

```go
import (
    "context"
    gohelper "gitee.com/linakesi/lzc-sdk/lang/go"
    "gitee.com/linakesi/lzc-sdk/lang/go/common"
)

func main() {
    ctx := context.TODO()

    gw, err := gohelper.NewAPIGateway(ctx)
    if err != nil {
        panic(err)
    }
    defer gw.Close()

    // 查询用户信息
    userInfo, _ := gw.Users.QueryUserInfo(ctx, &common.UserID{Uid: "lazycat"})
    fmt.Println("User:", userInfo.Nickname)

    // 列出设备
    devices, _ := gw.Devices.ListEndDevices(ctx, &common.ListEndDeviceRequest{Uid: "lazycat"})
    for _, d := range devices.Devices {
        fmt.Printf("Device: %s, Online: %v\n", d.Name, d.IsOnline)
    }
}
```

### JavaScript SDK

```javascript
import { lzcAPIGateway } from "@lazycatcloud/sdk"

const api = new lzcAPIGateway(window.location.origin, false)
const apps = await api.pkgm.QueryApplication({ appidList: [] })
console.log("Applications:", apps.infoList)
```

---

## 核心 API 概览

### Go SDK 服务

| 服务 | 用途 | 主要方法 |
|------|------|---------|
| `gw.Users` | 用户管理 | `QueryUserInfo` |
| `gw.Devices` | 设备管理 | `ListEndDevices` |
| `gw.Box` | 设备控制 | `QueryInfo`, `ChangePowerLed`, `Shutdown` |
| `gw.PkgManager` | 应用管理 | `QueryApplication`, `Resume`, `Pause` |

### 核心模式

```go
// 1. 创建 API Gateway
gw, err := gohelper.NewAPIGateway(ctx)
if err != nil {
    return err
}
defer gw.Close()  // 必须关闭！

// 2. 调用 SDK 方法
result, err := gw.Service.Method(ctx, &Request{...})
```

### HTTP Handler 中的用户上下文

LazyCat 通过 HTTP headers 注入用户信息：

```go
// 从 headers 提取
userID := c.GetHeader("x-hc-user-id")
userRole := c.GetHeader("x-hc-user-role")

// 添加到 gRPC context
ctx = metadata.AppendToOutgoingContext(ctx, "x-hc-user-id", userID)
```

**可用 Headers:**

| Header | 说明 |
|--------|------|
| `x-hc-user-id` | 当前用户 ID |
| `x-hc-user-role` | 用户角色 (`admin`, `user`) |
| `x-hc-device-id` | 设备 ID |
| `x-hc-device-version` | 设备版本 |

---

## 常用示例

### 1. 查询已安装应用

```go
resp, _ := gw.PkgManager.QueryApplication(ctx, &sys.QueryApplicationRequest{})
for _, app := range resp.InfoList {
    if app.Status == sys.AppStatus_Installed {
        fmt.Println("App:", app.Appid)
    }
}
```

### 2. 启动/暂停应用

```go
// 启动
gw.PkgManager.Resume(ctx, &sys.AppInstance{
    Appid: appID,
    Uid:   userID,
})

// 暂停
gw.PkgManager.Pause(ctx, &sys.AppInstance{
    Appid: appID,
    Uid:   userID,
})
```

### 3. 控制 LED

```go
// 获取当前状态
boxInfo, _ := gw.Box.QueryInfo(ctx, nil)
fmt.Println("LED on:", boxInfo.PowerLed)

// 切换 LED
gw.Box.ChangePowerLed(ctx, &common.ChangePowerLedRequest{
    PowerLed: !boxInfo.PowerLed,
})
```

### 4. 关机/重启

```go
// 重启
gw.Box.Shutdown(ctx, &common.ShutdownRequest{
    Action: common.ShutdownRequest_Reboot,
})

// 关机
gw.Box.Shutdown(ctx, &common.ShutdownRequest{
    Action: common.ShutdownRequest_Poweroff,
})
```

---

## 前端客户端能力

LazyCat iOS/Android 客户端为 WebShell 内运行的前端应用注入了丰富的原生能力。

### 环境判断

```js
import base from "@lazycatcloud/sdk/dist/extentions/base"

const isIOS = base.isIosWebShell()
const isAndroid = base.isAndroidWebShell()
const isClient = isIOS || isAndroid
```

### 能力矩阵概览

| 功能 | iOS | Android | 入口 |
|-----|-----|---------|------|
| 打开轻应用 | ✅ | ✅ | `AppCommon.LaunchApp` |
| 禁用暗黑模式 | ✅ | ✅ | `meta lzcapp-disable-dark` |
| 全屏控制 | ✅ | ✅ | `AppCommon.SetFullScreen` |
| 文件分享 | ✅ | ✅ | `AppCommon.ShareWithFiles` |
| 媒体分享 | ✅ | ✅ | `AppCommon.ShareMedia` |
| 导航栏 meta | ✅ | ❌ | `lzcapp-navigation-bar-scheme` |
| CSS 变量布局 | ✅ | ❌ | `--lzc-client-safearea-*` |
| 音量/亮度 | ✅ | ❌ | `AppCommon.GetDeviceVolume` |
| MediaSession | ❌ | ✅ | `MediaSession.*` |
| 状态栏颜色 | ❌ | ✅ | `lzc_window.SetStatusBarColor` |
| 控制栏显隐 | ❌ | ✅ | `lzc_tab.SetControlViewVisibility` |
| 主题模式 | ❌ | ✅ | `lzc_theme.getThemeMode` |
| 系统通知推送 | ✅ | ✅ | `currentDevice.notification.Notify` |

### AppCommon 快速示例

```js
import { AppCommon } from "@lazycatcloud/sdk/dist/extentions"

// 打开其他应用
await AppCommon.LaunchApp(url, "cloud.lazycat.app.photo")

// 进入全屏
await AppCommon.SetFullScreen()

// 分享文件
await AppCommon.ShareWithFiles("/path/to/file.pdf")
```

### 系统通知快速示例

```js
import { lzcAPIGateway } from "@lazycatcloud/sdk"
import base from "@lazycatcloud/sdk/dist/extentions/base"

const api = new lzcAPIGateway(window.location.origin, false)

// ⚠️ 检查点：非 WebShell 环境跳过
if (base.isIosWebShell() || base.isAndroidWebShell()) {
  try {
    const device = await api.currentDevice
    // ⚠️ 检查点：确认 notification 能力可用
    if (device?.notification?.Notify) {
      await device.notification.Notify({
        title: "任务完成",
        body: "导入任务已经处理完成",
        deeplinkUrl: "lzc://app/cloud.lazycat.app.demo",
      })
    }
  } catch (err) {
    console.error("[notification] send failed:", err)
  }
}
```

**⚠️ 前置条件**：`package.yml` 需声明 `user.notify` 权限（lzcos >= v1.6.0）

**❌ 不要做**：
- 不要在非 WebShell 环境直接调用（`device.notification` 为 undefined）
- 不要高频循环推送（系统可能限流）
- 不要把通知当数据同步通道（仅用于用户感知提醒）

详见 [references/frontend-extensions.md](references/frontend-extensions.md)

---

## 扩展模块

### minidb（类 MongoDB 数据库）

```javascript
import { Minidb } from "@lazycatcloud/minidb"
const db = new Minidb("myapp")

await db.insert({ name: "item1" })
await db.find({ name: "item1" })
await db.update({ name: "item1" }, { $set: { value: 200 } })
await db.remove({ name: "item1" })
```

### 文件选择器

```javascript
import { pickFiles } from "@lazycatcloud/lzc-file-pickers"

const files = await pickFiles({
  multiple: true,
  accept: [".pdf", ".doc"]
})
```

---

## 错误处理与边界条件

### 常见错误场景

| 场景 | 原因 | 解决方案 |
|------|------|---------|
| API Gateway 创建失败 | 网络不可达/服务未启动 | 返回错误，提示检查环境 |
| SDK 调用超时 | 服务响应慢 | 使用 `context.WithTimeout`，提供 fallback |
| 用户上下文缺失 | HTTP Handler 未传递 headers | 添加 `metadata.AppendToOutgoingContext` |
| defer gw.Close() 未执行 | panic 或提前退出 | 确保 defer 在创建后立即调用 |
| 前端环境判断错误 | 在非 WebShell 中调用原生能力 | 先用 `isIosWebShell()`/`isAndroidWebShell()` 判断 |
| 通知发送失败（无权限） | `package.yml` 未声明 `user.notify` | 检查 permissions 配置，确认 lzcos >= v1.6.0 |
| 通知发送失败（版本过低） | lzcos < v1.6.0 | 提示用户升级系统 |
| 通知不可达 | 设备离线或网络异常 | try/catch 捕获，降级为页面内提示 |

### 边界条件处理

| 边界情况 | 判断条件 | 处理方式 |
|---------|---------|---------|
| 空用户ID | `uid == ""` | 返回空结果，不调用 SDK |
| 空设备列表 | `resp.Devices == nil` | 返回 `[]Device{}`，不报错 |
| 离线设备操作 | `!device.IsOnline` | 提示用户设备离线，跳过操作 |
| 无权限操作 | `userRole != "admin"` | 返回权限错误，记录日志 |
| SDK 版本不匹配 | import 失败 | 提示更新 SDK 版本 |

### Fallback 模式示例

```go
func queryDevices(ctx context.Context, uid string) ([]Device, error) {
    // 边界条件：空用户ID
    if uid == "" {
        return []Device{}, nil
    }

    gw, err := gohelper.NewAPIGateway(ctx)
    if err != nil {
        // Fallback: 返回空列表而非失败
        return []Device{}, fmt.Errorf("gateway unavailable: %w", err)
    }
    defer gw.Close()

    ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
    defer cancel()

    resp, err := gw.Devices.ListEndDevices(ctx, &common.ListEndDeviceRequest{Uid: uid})
    if err != nil {
        // Fallback: 返回空列表，记录日志
        log.Printf("device query failed: %v", err)
        return []Device{}, nil
    }

    // 边界条件：空设备列表
    if resp.Devices == nil {
        return []Device{}, nil
    }

    return resp.Devices, nil
}
```

### 前端能力可用性检查

```js
import base from "@lazycatcloud/sdk/dist/extentions/base"
import { AppCommon } from "@lazycatcloud/sdk/dist/extentions"

// ⚠️ 检查点：调用原生能力前必须判断环境
const isClient = base.isIosWebShell() || base.isAndroidWebShell()

if (isClient) {
    // 安全调用原生能力
    await AppCommon.SetFullScreen()
} else {
    // Fallback: 浏览器兼容方案
    document.documentElement.requestFullscreen()
}
```

---

## 最佳实践

1. **总是关闭 API Gateway**: `defer gw.Close()`
2. **添加用户上下文**: `metadata.AppendToOutgoingContext(ctx, "x-hc-user-id", userID)`
3. **优雅处理错误**: SDK 调用可能失败，提供 fallback
4. **复用连接**: 每次操作创建一个 gateway，而非每次调用
5. **使用超时**: `context.WithTimeout(ctx, 10*time.Second)`

---

## 参考资料

- **官方文档**: https://developer.lazycat.cloud
- **SDK 仓库**: https://gitee.com/linakesi/lzc-sdk
- **npm 包**: https://www.npmjs.com/search?q=%40lazycatcloud