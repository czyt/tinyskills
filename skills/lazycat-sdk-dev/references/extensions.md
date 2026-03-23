# LazyCat Extensions Reference

LazyCat provides extension libraries for common use cases.

---

## minidb

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

### Supported Operators

| Operator | Description |
|----------|-------------|
| `$set` | Set field values |
| `$unset` | Remove fields |
| `$inc` | Increment numeric values |
| `$push` | Add to array |
| `$pull` | Remove from array |

### Query Operators

| Operator | Description |
|----------|-------------|
| `$eq` | Equal |
| `$ne` | Not equal |
| `$gt` | Greater than |
| `$gte` | Greater than or equal |
| `$lt` | Less than |
| `$lte` | Less than or equal |
| `$in` | In array |
| `$nin` | Not in array |

---

## File Pickers

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

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `multiple` | boolean | `false` | Allow multiple file selection |
| `accept` | string[] | `[]` | Accepted file extensions |
| `title` | string | - | Dialog title |

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | Full file path |
| `name` | string | File name |
| `size` | number | File size in bytes |
| `type` | string | MIME type |

---

## Cross-App Communication

Apps can communicate using service discovery:

```yaml
# In manifest.yml
services:
  myapp:
    environment:
      - TARGET_API=http://target-app.lzcapp:8080
```

### Service Discovery Pattern

- `http://{service-name}.lzcapp:port` - Access another service in the same app
- `http://{service-name}.{appid}.lzcapp:port` - Access a service in another app

### Example

```yaml
# App A: cloud.lazycat.app.api
services:
  api:
    ports:
      - "8080:8080"

# App B: cloud.lazycat.app.web
services:
  web:
    environment:
      - API_URL=http://api.cloud.lazycat.app.api.lzcapp:8080
```