---
name: lazycat-sdk-dev
description: LazyCat SDK development skill for building applications with Go and JavaScript/TypeScript SDKs. Use when developing apps that need to interact with LazyCat microservice system APIs, query app lists, manage devices, handle file pickers, or use minidb. Triggers when code imports @lazycatcloud/sdk, gitee.com/linakesi/lzc-sdk, or when user asks about LazyCat SDK, device management, app queries, or system integration.
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
| [references/go-sdk.md](references/go-sdk.md) | **Go SDK Complete Reference** - API Gateway, User/Device/Box/App management, HTTP handlers |
| [references/js-sdk.md](references/js-sdk.md) | **JavaScript/TypeScript SDK Reference** - Basic usage, API operations |
| [references/extensions.md](references/extensions.md) | **Extensions** - minidb, file-pickers, cross-app communication |

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