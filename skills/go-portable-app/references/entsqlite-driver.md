# lib-x/entsqlite 驱动详解

> 无 CGO 的 SQLite 驱动，支持任意平台交叉编译

**官方仓库**: https://github.com/lib-x/entsqlite

---

## 为什么选择 entsqlite

| 驱动 | CGO | 交叉编译 | 性能 | 维护状态 |
|------|-----|----------|------|----------|
| github.com/mattn/go-sqlite3 | ✅ 需要 | ❌ 困难 | 高 | 活跃 |
| modernc.org/sqlite | ❌ 无需 | ✅ 简单 | 中高 | 活跃 |
| **lib-x/entsqlite** | ❌ 无需 | ✅ 简单 | 高 | 活跃 |

---

## 安装

```bash
go get github.com/lib-x/entsqlite
```

---

## 关键配置

### 驱动名称

**⚠️ 必须使用 `"sqlite3"`，不是 `"sqlite"`**

```go
import (
    "your-project/ent"
    _ "github.com/lib-x/entsqlite"
)

client, err := ent.Open("sqlite3", dsn)  // 正确！
// client, err := ent.Open("sqlite", dsn) // 错误！
```

---

## 推荐连接参数

### 文件模式（推荐开发环境）

```go
dsn := "file:./data.db?" +
    "cache=shared&" +
    "_pragma=foreign_keys(1)&" +
    "_pragma=journal_mode(WAL)&" +
    "_pragma=synchronous(NORMAL)&" +
    "_pragma=busy_timeout(10000)"
```

### 内存模式（测试环境）

```go
// Basic memory database
dsn := "file::memory:?cache=shared&_pragma=foreign_keys(1)"

// Temporary database that's deleted when connection closes
dsn := "file:?mode=memory&cache=shared&_pragma=foreign_keys(1)"

// Named memory database that can be shared between connections
dsn := "file:memdb1?mode=memory&cache=shared&_pragma=foreign_keys(1)"
```

### 生产环境（只读）

```go
dsn := "file:./prod.db?mode=ro&cache=shared&_pragma=foreign_keys(1)"
```

---

## 参数详解

### 基础参数

| 参数 | 值 | 说明 |
|------|------|------|
| `file:./data.db` | 路径 | 数据库文件路径 |
| `cache` | `shared` | 多连接共享缓存，减少内存占用 |
| `mode` | `memory`/`ro`/`rw`/`rwc` | 内存模式/只读/读写/读写创建 |

### Pragma 参数（使用 `_pragma=name(value)` 格式）

| Pragma | 推荐值 | 说明 |
|--------|--------|------|
| `foreign_keys` | `1` | 启用外键约束 |
| `journal_mode` | `WAL` | **并发性能关键**，Write-Ahead Logging |
| `synchronous` | `NORMAL` | 平衡性能和数据安全（OFF/NORMAL/FULL） |
| `busy_timeout` | `10000` | 锁等待超时（毫秒），推荐 5-10 秒 |
| `temp_store` | `MEMORY` | 临时表存储在内存 |
| `mmap_size` | `30000000000` | 30GB mmap 大小，提升大数据库性能 |
| `cache_size` | `-2000` | 2MB 缓存（负值表示 KB） |

---

## 性能调优配置

### 完整优化配置（文件模式）

```go
dsn := "file:./data.db?" +
    "cache=shared&" +
    "_pragma=foreign_keys(1)&" +
    "_pragma=journal_mode(WAL)&" +
    "_pragma=synchronous(NORMAL)&" +
    "_pragma=busy_timeout(10000)&" +
    "_pragma=temp_store(MEMORY)&" +
    "_pragma=mmap_size(30000000000)&" +
    "_pragma=cache_size(-2000)"
```

### 内存模式优化配置

```go
dsn := "file::memory:?" +
    "cache=shared&" +
    "mode=memory&" +
    "_pragma=journal_mode(MEMORY)&" +
    "_pragma=synchronous(OFF)&" +
    "_pragma=foreign_keys(1)&" +
    "_pragma=temp_store(MEMORY)&" +
    "_pragma=cache_size(-2000)"
```

---

## WAL 模式详解

### 什么是 WAL

Write-Ahead Logging：写操作先记录到 WAL 文件，再异步合并到主数据库。

### 为什么重要

| 模式 | 并发读 | 并发写 | 性能 |
|------|--------|--------|------|
| DELETE（默认） | ❌ 阻塞 | ❌ 阻塞 | 低 |
| **WAL** | ✅ 不阻塞 | ⚠️ 串行 | 高 |

### 适用场景

- ✅ 开发环境：单机多连接
- ✅ 嵌入式应用：边缘计算、IoT
- ⚠️ 生产高并发：建议切换 PostgreSQL

---

## 并发支持

WAL 模式允许多个读者和单个写者并发操作：

```go
client, err := ent.Open("sqlite3",
    "file:./data.db?"+
    "cache=shared&"+                     // Enable shared cache
    "_pragma=journal_mode(WAL)&"+        // Enable WAL mode
    "_pragma=busy_timeout(10000)&"+      // Set busy timeout
    "_pragma=synchronous(NORMAL)",       // Set synchronous mode
)
```

---

## 交叉编译

entsqlite 无 CGO，可直接交叉编译：

```bash
# Linux AMD64
GOOS=linux GOARCH=amd64 go build -o bin/app-linux ./cmd/app

# Windows AMD64
GOOS=windows GOARCH=amd64 go build -o bin/app-windows.exe ./cmd/app

# macOS ARM64
GOOS=darwin GOARCH=arm64 go build -o bin/app-darwin-arm ./cmd/app

# Linux ARM（树莓派等）
GOOS=linux GOARCH=arm GOARM=7 go build -o bin/app-arm ./cmd/app
```

---

## 错误处理

```go
if err != nil {
    log.Fatalf("failed opening connection to sqlite: %v", err)
}
defer client.Close()
```

---

## enttest 配置

```go
func TestWithEntsqlite(t *testing.T) {
    // 使用 entsqlite 内存数据库
    client := enttest.Open(t, "sqlite3", 
        "file:ent?mode=memory&cache=shared&_pragma=foreign_keys(1)")
    defer client.Close()
    
    // 自动迁移
    ctx := context.Background()
    if err := client.Schema.Create(ctx); err != nil {
        t.Fatal(err)
    }
    
    // 测试...
}
```

---

## 最佳实践

1. **总是使用 WAL 模式**用于并发访问
2. **设置适当的 busy_timeout**（5-10秒）
3. **启用 foreign_keys**保证数据完整性
4. **使用 shared cache**提升并发性能
5. **调整 cache_size**根据数据大小
6. **考虑 mmap**用于大型数据库
7. **监控数据库性能**并调整参数

---

## 限制

1. SQLite 不适合高并发
2. 单写者限制
3. 文件系统性能限制
4. 不适合高流量 Web 应用

---

## 常见问题

### 驱动名称错误

```
ent: dialect "sqlite" is not supported
```

**解决**：改用 `"sqlite3"`

### 编译失败（CGO）

```
# runtime/cgo
error:...
```

**解决**：确认使用 entsqlite，设置 `CGO_ENABLED=0`

### 并发写入阻塞

```
database is locked
```

**解决**：
1. 添加 `_pragma=journal_mode(WAL)`
2. 增加 `_pragma=busy_timeout(10000)`
3. 或切换到 PostgreSQL

---

## 与其他驱动对比

### go-sqlite3（mattn）

```go
import _ "github.com/mattn/go-sqlite3"

// 需要 CGO，交叉编译困难
client, err := ent.Open("sqlite3", dsn)
```

### modernc.org/sqlite

```go
import _ "modernc.org/sqlite"

// 无 CGO，但 ent 需要额外配置
client, err := ent.Open("sqlite", dsn)  // 驱动名不同
```

### entsqlite（推荐）

```go
import _ "github.com/lib-x/entsqlite"

// 无 CGO，ent 直接支持
client, err := ent.Open("sqlite3", dsn)  // 驱动名 sqlite3
```

---

## 配置模板

```go
package conf

import (
    "os"
    "your-project/ent"
    _ "github.com/lib-x/entsqlite"
)

type DatabaseConfig struct {
    Driver     string
    DSN        string
    AutoMigrate bool
}

func NewEntClient(cfg *DatabaseConfig) (*ent.Client, error) {
    client, err := ent.Open(cfg.Driver, cfg.DSN)
    if err != nil {
        return nil, err
    }
    
    if cfg.AutoMigrate {
        if err := client.Schema.Create(context.Background()); err != nil {
            return nil, err
        }
    }
    
    return client, nil
}

func LoadDatabaseConfig() DatabaseConfig {
    env := os.Getenv("APP_ENV")
    
    switch env {
    case "prod":
        return DatabaseConfig{
            Driver:     "postgres",
            DSN:        os.Getenv("DATABASE_URL"),
            AutoMigrate: false,
        }
    case "test":
        return DatabaseConfig{
            Driver:     "sqlite3",
            DSN:        "file::memory:?cache=shared&_pragma=foreign_keys(1)",
            AutoMigrate: true,
        }
    default: // dev
        return DatabaseConfig{
            Driver:     "sqlite3",
            DSN:        "file:./app.db?cache=shared&_pragma=foreign_keys(1)&_pragma=journal_mode(WAL)&_pragma=synchronous(NORMAL)&_pragma=busy_timeout(10000)",
            AutoMigrate: true,
        }
    }
}
```

---

## 参考资料

- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [SQLite PRAGMA Statements](https://www.sqlite.org/pragma.html)
- [SQLite WAL Mode](https://www.sqlite.org/wal.html)