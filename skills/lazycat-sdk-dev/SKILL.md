---
name: lazycat-sdk-dev
description: LazyCat SDK development skill for building applications with Go and JavaScript/TypeScript SDKs. Use when developing apps that need to interact with LazyCat microservice system APIs, query app lists, manage devices, handle file pickers, or use minidb. Triggers when code imports @lazycatcloud/sdk, gitee.com/linakesi/lzc-sdk, or when user asks about LazyCat SDK, device management, app queries, or system integration.
---

# LazyCat SDK Development

This skill helps you develop applications that interact with the LazyCat microservice system using the official SDKs.

## Supported Languages

- **JavaScript/TypeScript** - `@lazycatcloud/sdk` (npm)
- **Go** - `gitee.com/linakesi/lzc-sdk/lang/go`

More languages coming soon: Rust, Dart, Cpp, Java, Python, Ruby, C#, PHP, Objective-C, Kotlin.

## Extensions

LazyCat also provides these extension libraries:

| Package | Purpose |
|---------|---------|
| `@lazycatcloud/minidb` | Small MongoDB-like database for serverless apps |
| `@lazycatcloud/lzc-file-pickers` | File picker for LazyCat storage integration |

---

## JavaScript/TypeScript SDK

### Installation

```bash
npm install @lazycatcloud/sdk
# or
pnpm install @lazycatcloud/sdk
```

### Basic Usage

The JS/TS SDK uses grpc-web to provide services.

```javascript
import { lzcAPIGateway } from "@lazycatcloud/sdk"

// Initialize lzcapi
const lzcapi = new lzcAPIGateway(window.location.origin, false)

// Query all applications
const apps = await lzcapi.pkgm.QueryApplication({ appidList: [] })
console.debug("applications: ", apps)
```

### Response Example

```json
{
  "infoList": [
    {
      "appid": "cloud.lazycat.developer.tools",
      "status": 4,
      "version": "0.1.3",
      "title": "LCMD Cloud Developer Tools",
      "description": "",
      "icon": "//lcc.heiyu.space/sys/icons/cloud.lazycat.developer.tools.png",
      "domain": "dev.lcc.heiyu.space",
      "builtin": false,
      "unsupportedPlatforms": []
    }
  ]
}
```

### Common API Operations

#### Get Application List

```javascript
const apps = await lzcapi.pkgm.QueryApplication({ appidList: [] })
```

#### Get Specific Applications

```javascript
const apps = await lzcapi.pkgm.QueryApplication({
  appidList: ["cloud.lazycat.app.myapp"]
})
```

---

## Go SDK

### Installation

```bash
go get -u gitee.com/linakesi/lzc-sdk/lang/go
```

### Basic Usage

```go
package main

import (
    "context"
    "fmt"

    lzcsdk "gitee.com/linakesi/lzc-sdk/lang/go"
    "gitee.com/linakesi/lzc-sdk/lang/go/common"
)

func main() {
    ctx := context.TODO()

    // Initialize LzcAPI
    lzcapi, err := lzcsdk.NewAPIGateway(ctx)
    if err != nil {
        fmt.Println("Initial Lzc Api failed:", err)
        return
    }

    // Build request - get all devices for user "lazycat"
    request := &common.ListEndDeviceRequest{
        Uid: "lazycat"
    }

    // Get all devices
    devices, err := lzcapi.Devices.ListEndDevices(ctx, request)
    if devices == nil {
        fmt.Println("lazycat has no devices")
        return
    }

    var onLineDevices []*common.EndDevice
    for _, device := range devices.Devices {
        d := device
        // Check if device is online
        if d.IsOnline {
            onLineDevices = append(onLineDevices, d)
            fmt.Printf("%s device is online\n", d.Name)
        }
    }
    fmt.Printf("There are %d online devices\n", len(onLineDevices))
}
```

### Output Example

```
evan device is online
wwh device is online
There are 2 online devices
```

---

## Using minidb Extension

`@lazycatcloud/minidb` is a small MongoDB-like database for serverless applications.

### Installation

```bash
npm install @lazycatcloud/minidb
```

### Usage Pattern

```javascript
import { Minidb } from "@lazycatcloud/minidb"

// Initialize database
const db = new Minidb("myapp")

// Insert document
await db.insert({ name: "item1", value: 100 })

// Query documents
const items = await db.find({ name: "item1" })

// Update document
await db.update({ name: "item1" }, { $set: { value: 200 } })

// Delete document
await db.remove({ name: "item1" })
```

---

## Using File Pickers Extension

`@lazycatcloud/lzc-file-pickers` allows your app to open files from LazyCat storage.

### Installation

```bash
npm install @lazycatcloud/lzc-file-pickers
```

### Usage Pattern

```javascript
import { pickFiles } from "@lazycatcloud/lzc-file-pickers"

// Open file picker
const files = await pickFiles({
  multiple: true,
  accept: [".pdf", ".doc", ".docx"]
})

// Handle selected files
for (const file of files) {
  console.log("Selected file:", file.path, file.name)
}
```

---

## Integration in LazyCat Applications

### Frontend Integration

For web applications running inside LazyCat:

```javascript
// In your Vue/React/etc app
import { lzcAPIGateway } from "@lazycatcloud/sdk"

// Use window.location.origin for automatic endpoint detection
const api = new lzcAPIGateway(window.location.origin, false)

export async function getAppInfo(appid) {
  const result = await api.pkgm.QueryApplication({ appidList: [appid] })
  return result.infoList[0]
}
```

### Backend Integration (Go)

For backend services that need system integration:

```go
// In your Go backend
func GetOnlineDevices(ctx context.Context) ([]string, error) {
    lzcapi, err := lzcsdk.NewAPIGateway(ctx)
    if err != nil {
        return nil, err
    }

    // Get current user's devices
    request := &common.ListEndDeviceRequest{
        Uid: "", // Empty = current user
    }

    devices, err := lzcapi.Devices.ListEndDevices(ctx, request)
    if err != nil {
        return nil, err
    }

    var online []string
    for _, d := range devices.Devices {
        if d.IsOnline {
            online = append(online, d.Name)
        }
    }
    return online, nil
}
```

---

## Common Use Cases

### 1. App Status Checking

Check if another app is installed and running:

```javascript
const apps = await lzcapi.pkgm.QueryApplication({
  appidList: ["cloud.lazycat.app.target"]
})

if (apps.infoList.length > 0 && apps.infoList[0].status === 4) {
  console.log("Target app is running")
}
```

### 2. Device Management

List and manage connected devices:

```go
devices, _ := lzcapi.Devices.ListEndDevices(ctx, &common.ListEndDeviceRequest{})

for _, d := range devices.Devices {
    fmt.Printf("Device: %s, Online: %v\n", d.Name, d.IsOnline)
}
```

### 3. Cross-App Communication

Apps can communicate using service discovery:

```yaml
# In manifest.yml
services:
  myapp:
    environment:
      - TARGET_API=http://target-app.lzcapp:8080
```

---

## Best Practices

1. **Error Handling** - Always handle SDK initialization errors
2. **Context Usage** - Use proper context for timeout and cancellation
3. **Connection Reuse** - Initialize API gateway once and reuse
4. **Lazy Loading** - Load SDK only when needed in frontend

## References

- **Official Docs**: https://developer.lazycat.cloud
- **SDK Repository**: https://gitee.com/linakesi/lzc-sdk
- **npm Packages**: https://www.npmjs.com/search?q=%40lazycatcloud