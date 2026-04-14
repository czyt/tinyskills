---
name: lazycat-sdk-dev
description: LazyCat SDK development skill for building applications with Go and JavaScript/TypeScript SDKs, including frontend client capabilities for iOS/Android WebShell. Use when developing apps that need to interact with LazyCat microservice system APIs, query app lists, manage devices, handle file pickers, use minidb, or access client-side capabilities like AppCommon, MediaSession, navigation bar meta, full screen control, file/media sharing, theme mode, and platform-specific features. Triggers when code imports @lazycatcloud/sdk, gitee.com/linakesi/lzc-sdk, or when user asks about LazyCat SDK, client WebShell, device management, app queries, frontend extensions, or system integration.
---

# LazyCat SDK Development

This skill helps you develop applications that interact with the LazyCat microservice system using the official SDKs.

## Supported Languages

| Language | Package | Import Path |
|----------|---------|-------------|
| **Go** | `gitee.com/linakesi/lzc-sdk` | `gitee.com/linakesi/lzc-sdk/lang/go` |
| **JavaScript/TypeScript** | `@lazycatcloud/sdk` | npm package |

More languages coming soon: Rust, Dart, Cpp, Java, Python, Ruby, C#, PHP, Objective-C, Kotlin.

## Reference Documents

| Document | Content |
|----------|---------|
| [references/frontend-extensions.md](references/frontend-extensions.md) | **前端客户端能力** - iOS/Android WebShell 能力矩阵，AppCommon API，导航栏/状态栏 meta，MediaSession 等 |
| [references/go-sdk.md](references/go-sdk.md) | **Go SDK Complete Reference** - API Gateway, User/Device/Box/App management, HTTP handlers |
| [references/js-sdk.md](references/js-sdk.md) | **JavaScript/TypeScript SDK Reference** - Basic usage, API operations, frontend integration |
| [references/extensions.md](references/extensions.md) | **Extensions** - minidb, file-pickers, cross-app communication |

---

## Development Workflow

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

#### Step 2.2: 添加用户上下文（HTTP Handler 必须）

**⚠️ 检查点**: 如果是 HTTP Handler，必须传递用户上下文

```go
// 从 HTTP headers 提取
userID := c.GetHeader("x-hc-user-id")

// 添加到 gRPC context
ctx = metadata.AppendToOutgoingContext(ctx, "x-hc-user-id", userID)
```

#### Step 2.3: 编写业务代码

参考 [Common Use Cases](#common-use-cases) 或具体 reference 文档。

### Phase 3: 错误处理与测试

**输入**: 业务代码完成
**输出**: 稳定运行，错误有 fallback

#### Step 3.1: 添加超时控制

```go
ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
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

## Quick Start

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

    // Query user info
    userInfo, _ := gw.Users.QueryUserInfo(ctx, &common.UserID{Uid: "lazycat"})
    fmt.Println("User:", userInfo.Nickname)

    // List devices
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

## Core APIs Overview

### Go SDK Services

| Service | Purpose | Key Methods |
|---------|---------|-------------|
| `gw.Users` | User management | `QueryUserInfo` |
| `gw.Devices` | Device management | `ListEndDevices` |
| `gw.Box` | Device control | `QueryInfo`, `ChangePowerLed`, `Shutdown` |
| `gw.PkgManager` | App management | `QueryApplication`, `Resume`, `Pause` |

### Core Pattern

```go
// 1. Create API Gateway
gw, err := gohelper.NewAPIGateway(ctx)
if err != nil {
    return err
}
defer gw.Close()  // Always close!

// 2. Call SDK methods
result, err := gw.Service.Method(ctx, &Request{...})
```

### User Context in HTTP Handlers

LazyCat injects user info via HTTP headers:

```go
// Extract from headers
userID := c.GetHeader("x-hc-user-id")
userRole := c.GetHeader("x-hc-user-role")

// Add to gRPC context
ctx = metadata.AppendToOutgoingContext(ctx, "x-hc-user-id", userID)
```

**Available Headers:**

| Header | Description |
|--------|-------------|
| `x-hc-user-id` | Current user ID |
| `x-hc-user-role` | User role (`admin`, `user`) |
| `x-hc-device-id` | Device ID |
| `x-hc-device-version` | Device version |

---

## Common Use Cases

### 1. Query Installed Apps

```go
resp, _ := gw.PkgManager.QueryApplication(ctx, &sys.QueryApplicationRequest{})
for _, app := range resp.InfoList {
    if app.Status == sys.AppStatus_Installed {
        fmt.Println("App:", app.Appid)
    }
}
```

### 2. Resume/Pause Application

```go
// Resume
gw.PkgManager.Resume(ctx, &sys.AppInstance{
    Appid: appID,
    Uid:   userID,
})

// Pause
gw.PkgManager.Pause(ctx, &sys.AppInstance{
    Appid: appID,
    Uid:   userID,
})
```

### 3. Control LED

```go
// Get current status
boxInfo, _ := gw.Box.QueryInfo(ctx, nil)
fmt.Println("LED on:", boxInfo.PowerLed)

// Toggle LED
gw.Box.ChangePowerLed(ctx, &common.ChangePowerLedRequest{
    PowerLed: !boxInfo.PowerLed,
})
```

### 4. Shutdown/Reboot

```go
// Reboot
gw.Box.Shutdown(ctx, &common.ShutdownRequest{
    Action: common.ShutdownRequest_Reboot,
})

// Power off
gw.Box.Shutdown(ctx, &common.ShutdownRequest{
    Action: common.ShutdownRequest_Poweroff,
})
```

---

## Frontend Client Capabilities

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

详见 [references/frontend-extensions.md](references/frontend-extensions.md)

---

## Extensions

### minidb (MongoDB-like database)

```javascript
import { Minidb } from "@lazycatcloud/minidb"
const db = new Minidb("myapp")

await db.insert({ name: "item1" })
await db.find({ name: "item1" })
await db.update({ name: "item1" }, { $set: { value: 200 } })
await db.remove({ name: "item1" })
```

### File Pickers

```javascript
import { pickFiles } from "@lazycatcloud/lzc-file-pickers"

const files = await pickFiles({
  multiple: true,
  accept: [".pdf", ".doc"]
})
```

---

## Error Handling & Edge Cases

### 常见错误场景

| 场景 | 原因 | 解决方案 |
|------|------|---------|
| API Gateway 创建失败 | 网络不可达/服务未启动 | 返回错误，提示检查环境 |
| SDK 调用超时 | 服务响应慢 | 使用 `context.WithTimeout`，提供 fallback |
| 用户上下文缺失 | HTTP Handler 未传递 headers | 添加 `metadata.AppendToOutgoingContext` |
| defer gw.Close() 未执行 | panic 或提前退出 | 确保 defer 在创建后立即调用 |
| 前端环境判断错误 | 在非 WebShell 中调用原生能力 | 先用 `isIosWebShell()`/`isAndroidWebShell()` 判断 |

### Fallback 模式示例

```go
func queryDevices(ctx context.Context, uid string) ([]Device, error) {
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

## Best Practices

1. **Always close API Gateway**: `defer gw.Close()`
2. **Add user context**: `metadata.AppendToOutgoingContext(ctx, "x-hc-user-id", userID)`
3. **Handle errors gracefully**: SDK calls may fail, provide fallbacks
4. **Reuse connections**: Create one gateway per operation, not per call
5. **Use timeouts**: `context.WithTimeout(ctx, 10*time.Second)`

---

## References

- **Official Docs**: https://developer.lazycat.cloud
- **SDK Repository**: https://gitee.com/linakesi/lzc-sdk
- **npm Packages**: https://www.npmjs.com/search?q=%40lazycatcloud