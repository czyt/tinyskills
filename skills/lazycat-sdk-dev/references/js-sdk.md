# JavaScript/TypeScript SDK Reference

## Installation

```bash
npm install @lazycatcloud/sdk
# or
pnpm install @lazycatcloud/sdk
```

---

## Basic Usage

The JS/TS SDK uses grpc-web to provide services.

```javascript
import { lzcAPIGateway } from "@lazycatcloud/sdk"

// Initialize lzcapi
const lzcapi = new lzcAPIGateway(window.location.origin, false)

// Query all applications
const apps = await lzcapi.pkgm.QueryApplication({ appidList: [] })
console.debug("applications: ", apps)
```

---

## Response Example

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

---

## Common API Operations

### Get Application List

```javascript
const apps = await lzcapi.pkgm.QueryApplication({ appidList: [] })
```

### Get Specific Applications

```javascript
const apps = await lzcapi.pkgm.QueryApplication({
  appidList: ["cloud.lazycat.app.myapp"]
})
```

### Check App Status

```javascript
const apps = await lzcapi.pkgm.QueryApplication({
  appidList: ["cloud.lazycat.app.target"]
})

if (apps.infoList.length > 0 && apps.infoList[0].status === 4) {
  console.log("Target app is running")
}
```

---

## Frontend Integration

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

---

## Best Practices

### 1. Lazy Loading

Load SDK only when needed in frontend applications:

```javascript
// Lazy import
const { lzcAPIGateway } = await import("@lazycatcloud/sdk")
```

### 2. Error Handling

```javascript
try {
  const apps = await lzcapi.pkgm.QueryApplication({ appidList: [] })
  // Handle success
} catch (error) {
  console.error("Failed to query applications:", error)
  // Handle error gracefully
}
```

### 3. Connection Reuse

Initialize the API gateway once and reuse:

```javascript
// Create once, use everywhere
let api = null

export function getAPI() {
  if (!api) {
    api = new lzcAPIGateway(window.location.origin, false)
  }
  return api
}
```