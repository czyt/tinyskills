---
name: go-portable-app
description: Go portable application development agent for single-file deployment. Focuses on ent ORM + SQLite (entsqlite driver) + embed frontend + Wire/fx dependency injection. Use when developing Go apps with embedded resources, single-binary deployment, cross-platform compilation, or SQLite-based apps. Triggers: "portable go app", "单文件部署", "go embed", "entsqlite", "go portable", "嵌入式go应用", "single binary go", "cross compile go", "wire", "fx", "依赖注入".
---

# Go Portable Application Development

构建**单文件部署**的 Go 应用：前端嵌入 + SQLite 数据库 + 无 CGO 交叉编译 + Wire/fx 依赖注入。

---

## 核心原则

1. **单文件优先**：所有资源（前端、配置、数据库）打包进单个二进制文件
2. **无 CGO 编译**：使用 `lib-x/entsqlite` 驱动，支持任意平台交叉编译
3. **开发用 SQLite**：单文件数据库，WAL 模式提升并发
4. **生产可切换**：ent 多驱动支持，生产环境切换 PostgreSQL
5. **依赖注入可选**：Wire（编译时，推荐）或 fx（运行时）

---

## 1. 项目结构

```
cmd/
  └── app/
      └── main.go          # 应用入口（embed 配置）
internal/
  ├── server/              # HTTP/gRPC 服务器
  ├── handler/             # HTTP handlers
  ├── service/             # 业务逻辑层
  ├── data/                # 数据访问层（ent）
  ├── middleware/          # 中间件
  └── conf/                # 配置管理
ent/
  └── schema/              # ent schema 定义
web/
  └── dist/                # 前端编译产物（embed）
configs/
  └── config.yaml          # 配置文件
scripts/
  └── build.sh             # 构建脚本
test/
  └── integration/         # 集成测试
```

### Embed 配置示例

```go
// cmd/app/main.go
package main

import (
    "embed"
    "io/fs"
    "net/http"
    
    "github.com/labstack/echo/v5"
)

//go:embed web/dist
var webFS embed.FS

func main() {
    e := echo.New()
    
    // API 路由
    api := e.Group("/api/v1")
    api.GET("/users", getUsersHandler)
    
    // 前端路由（兜底）
    distFS, _ := fs.Sub(webFS, "web/dist")
    e.GET("/*", echo.WrapHandler(http.FileServer(http.FS(distFS))))
    
    e.Start(":8080")
}
```

---

## 2. 数据库配置（SQLite + ent）

### 使用 entsqlite 驱动（无 CGO）

**关键：驱动名称是 `"sqlite3"`，不是 `"sqlite"`**

```go
import (
    "your-project/ent"
    _ "github.com/lib-x/entsqlite"  // 无 CGO 驱动
)

// 开发环境（推荐配置）
client, err := ent.Open("sqlite3", 
    "file:./data.db?" +
    "cache=shared&" +
    "_pragma=foreign_keys(1)&" +
    "_pragma=journal_mode(WAL)&" +      // 并发性能提升！
    "_pragma=synchronous(NORMAL)&" +
    "_pragma=busy_timeout(10000)")
```

### 连接参数说明

- `cache=shared`: 多连接共享缓存
- `_pragma=foreign_keys(1)`: 启用外键约束
- `_pragma=journal_mode(WAL)`: **并发性能提升关键**
- `_pragma=synchronous(NORMAL)`: 平衡性能和安全
- `_pragma=busy_timeout(10000)`: 锁等待超时（10秒）

### 多环境配置

```go
type DatabaseConfig struct {
    Driver string
    DSN    string
}

func LoadDatabaseConfig(env string) DatabaseConfig {
    switch env {
    case "dev":
        return DatabaseConfig{
            Driver: "sqlite3",
            DSN:    "file:./dev.db?cache=shared&_pragma=foreign_keys(1)&_pragma=journal_mode(WAL)&_pragma=synchronous(NORMAL)&_pragma=busy_timeout(10000)",
        }
    case "test":
        return DatabaseConfig{
            Driver: "sqlite3",
            DSN:    "file::memory:?cache=shared&_pragma=foreign_keys(1)",
        }
    case "prod":
        return DatabaseConfig{
            Driver: "postgres",
            DSN:    os.Getenv("DATABASE_URL"),
        }
    default:
        return DatabaseConfig{
            Driver: "sqlite3",
            DSN:    "file:./app.db?cache=shared&_pragma=foreign_keys(1)&_pragma=journal_mode(WAL)&_pragma=synchronous(NORMAL)&_pragma=busy_timeout(10000)",
        }
    }
}
```

---

## 3. 构建与部署

### 开发构建

```bash
# 开发环境（自动迁移）
go run ./cmd/app

# 热重载
air
```

### 生产构建（嵌入前端）

```bash
# 1. 构建前端
cd web && npm run build

# 2. 构建后端（嵌入前端）
go build -tags embed -ldflags="-s -w" -o bin/app ./cmd/app

# 3. 单文件部署
./bin/app
```

### 交叉编译（无 CGO）

```bash
# Linux
GOOS=linux GOARCH=amd64 go build -tags embed -o bin/app-linux ./cmd/app

# Windows
GOOS=windows GOARCH=amd64 go build -tags embed -o bin/app-windows.exe ./cmd/app

# macOS ARM
GOOS=darwin GOARCH=arm64 go build -tags embed -o bin/app-darwin-arm ./cmd/app
```

---

## 4. Ent Schema 与迁移

### Schema 定义

```go
// ent/schema/user.go
type User struct {
    ent.Schema
}

func (User) Fields() []ent.Field {
    return []ent.Field{
        field.UUID("id", uuid.UUID{}).Default(uuid.New),
        field.String("username").Unique(),
        field.String("email").Unique(),
        field.String("password_hash").Sensitive(),
        field.Time("created_at").Default(time.Now).Immutable(),
        field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
    }
}

func (User) Indexes() []ent.Index {
    return []ent.Index{
        index.Fields("username"),
        index.Fields("email"),
    }
}
```

### 生成代码

```bash
# 创建 schema
go run -mod=mod entgo.io/ent/cmd/ent new User

# 生成代码
go generate ./ent
```

### 迁移（使用 Atlas）

```bash
# 创建迁移
atlas migrate diff create_users \
  --dir "file://ent/migrate/migrations" \
  --to "ent://ent/schema" \
  --dev-url "sqlite://file?mode=memory&_pragma=foreign_keys(1)"

# 应用迁移
atlas migrate apply \
  --dir "file://ent/migrate/migrations" \
  --url "sqlite://file:./dev.db?_pragma=foreign_keys(1)"
```

---

## 5. 测试策略

### 单元测试（enttest）

```go
func TestUserService(t *testing.T) {
    // SQLite 内存数据库
    client := enttest.Open(t, "sqlite3", 
        "file:ent?mode=memory&cache=shared&_pragma=foreign_keys(1)")
    defer client.Close()
    
    // 自动迁移
    ctx := context.Background()
    if err := client.Schema.Create(ctx); err != nil {
        t.Fatal(err)
    }
    
    // 测试业务逻辑
    user, err := client.User.
        Create().
        SetUsername("test").
        SetEmail("test@example.com").
        Save(ctx)
    
    require.NoError(t, err)
    assert.Equal(t, "test", user.Username)
}
```

### 集成测试

```bash
# 运行所有测试
go test ./...

# 带覆盖率
go test -cover ./...

# 集成测试
go test -tags=integration ./test/...
```

---

## 6. Dockerfile（单文件部署）

```dockerfile
# 多阶段构建
FROM node:18-alpine AS frontend-builder
WORKDIR /frontend
COPY web/package*.json ./
RUN npm ci
COPY web/ ./
RUN npm run build

FROM golang:1.21-alpine AS backend-builder
RUN apk add --no-cache git make
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=frontend-builder /frontend/dist ./web/dist
RUN go generate ./ent
RUN CGO_ENABLED=0 GOOS=linux go build \
    -tags embed -ldflags="-s -w" \
    -o /app/bin/app ./cmd/app

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /app
COPY --from=backend-builder /app/bin/app .
RUN mkdir -p /app/data
EXPOSE 8080
CMD ["./app"]
```

### Docker 运行

```bash
docker build -t myapp:latest .
docker run -d -p 8080:8080 -v $(pwd)/data:/app/data myapp:latest
```

---

## 7. CI/CD 配置

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-go@v6
        with:
          go-version: '1.21'
      
      - name: Build frontend
        if: hashFiles('web/package.json') != ''
        uses: actions/setup-node@v6
        with:
          node-version: '18'
        run: |
          cd web && npm ci && npm run build
      
      - name: Generate code
        run: go generate ./ent
      
      - name: Run tests
        run: go test -v -race -coverprofile=coverage.out ./...
      
      - name: Build
        run: go build -tags embed -ldflags="-s -w" -o bin/app ./cmd/app
      
      - name: Cross compile
        run: |
          GOOS=linux GOARCH=amd64 go build -tags embed -o bin/app-linux ./cmd/app
          GOOS=windows GOARCH=amd64 go build -tags embed -o bin/app-windows.exe ./cmd/app
          GOOS=darwin GOARCH=arm64 go build -tags embed -o bin/app-darwin-arm ./cmd/app
```

---

## 8. 工作流程

### 新项目初始化

1. **确认需求** → 向用户确认：项目名、主要功能、前端技术栈
2. 创建项目结构
3. 配置 `go.mod`（添加 `lib-x/entsqlite`）
4. 定义 ent schema → **用户审核** schema 设计
5. 创建前端项目（`web/`）
6. 配置 embed
7. 编写构建脚本 → **用户确认** 构建方案

### 新功能开发

1. 更新 ent schema（如有）→ **用户审核** schema 变更
2. 实现 data layer（`internal/data/`）
3. 实现 service layer（`internal/service/`）
4. 实现 handler（`internal/handler/`）
5. 编写测试
6. 验证构建 → **用户确认** 测试结果

### 发布流程

1. 构建前端：`cd web && npm run build`
2. 运行测试：`go test ./...` → **检查点**：测试必须通过
3. 生成代码：`go generate ./ent`
4. 构建二进制：`go build -tags embed -o bin/app ./cmd/app`
5. 交叉编译（可选）
6. Docker 构建（可选）→ **用户确认** 部署方案

---

## 9. 错误处理（Ent）

```go
// Handler 中的错误处理
func (h *UserHandler) Register(c echo.Context) error {
    user, err := h.userService.CreateUser(c.Request().Context(), &req)
    if err != nil {
        if ent.IsConstraintError(err) {
            return echo.NewHTTPError(http.StatusConflict, 
                "username or email already exists")
        }
        if ent.IsNotFound(err) {
            return echo.NewHTTPError(http.StatusNotFound, "user not found")
        }
        return echo.NewHTTPError(http.StatusInternalServerError, 
            "failed to create user")
    }
    return c.JSON(http.StatusCreated, user)
}
```

---

## 10. 性能优化

### Ent 查询优化

```go
// Eager Loading 避免 N+1
users, err := client.User.
    Query().
    WithPosts().
    WithComments().
    All(ctx)

// 批量操作
bulk := make([]*ent.UserCreate, len(users))
for i, u := range users {
    bulk[i] = client.User.Create().SetName(u.Name)
}
users, err := client.User.CreateBulk(bulk...).Save(ctx)
```

### SQLite WAL 模式

**已在连接参数中配置**，无需额外代码。

---

## 关键约束

1. **驱动名称必须是 `"sqlite3"`**（使用 entsqlite）
2. **构建标签 `-tags embed`**（嵌入前端）
3. **禁用 CGO**（交叉编译要求）
4. **生产环境考虑 PostgreSQL**（高并发场景）

---

## 边界条件与 Fallback

### 常见问题处理

| 问题 | 检测方式 | Fallback 方案 |
|------|---------|--------------|
| 前端构建失败 | `npm run build` 报错 | 检查 node 版本、依赖完整性 |
| embed 找不到文件 | `embed: pattern matches no files` | 确认 `web/dist` 存在，先构建前端 |
| SQLite 驱动错误 | `dialect "sqlite" is not supported` | 确认导入 `lib-x/entsqlite`，驱动名 `"sqlite3"` |
| 数据库锁定 | `database is locked` | 已配置 `busy_timeout(10000)`，如频繁发生考虑 PostgreSQL |
| CGO 编译失败 | `# runtime/cgo` 错误 | 确认 `CGO_ENABLED=0`，不导入需要 CGO 的包 |
| 交叉编译失败 | 构建报错 | 检查 GOOS/GOARCH 组合是否正确 |

### 开发环境 Fallback

如果 SQLite 不满足需求：
1. **测试环境** → 使用内存数据库 `file::memory:?cache=shared`
2. **开发环境** → 切换 PostgreSQL（ent 支持多驱动）
3. **生产环境** → 必须切换 PostgreSQL 或 MySQL

### 前端嵌入 Fallback

如果前端未构建：
```bash
# 开发模式：不嵌入，直接读取本地文件
go run ./cmd/app  # 不加 -tags embed

# 生产模式：必须先构建前端
cd web && npm run build
go build -tags embed -o bin/app ./cmd/app
```

### 迁移失败处理

```bash
# Atlas 迁移冲突
atlas migrate hash --dir "file://ent/migrate/migrations"  # 重新生成校验

# 回滚到指定版本
atlas migrate down --dir ... --url ... --to <version>
```

## 工具推荐

- **热重载**: `air`
- **Web 框架**: Echo v5（最新版）
- **数据库驱动**: `lib-x/entsqlite`
- **迁移**: `atlas`
- **前端**: Vue/React（编译到 `web/dist`）
- **依赖注入**: Wire（推荐，编译时）或 fx（运行时）

---

## Quick Reference

| 操作 | 命令 |
|------|------|
| 开发运行 | `go run ./cmd/app` |
| 热重载 | `air` |
| 构建前端 | `cd web && npm run build` |
| 构建后端 | `go build -tags embed -o bin/app ./cmd/app` |
| 交叉编译 | `GOOS=linux GOARCH=amd64 go build -tags embed ...` |
| 测试 | `go test ./...` |
| Ent 生成 | `go generate ./ent` |
| Wire 生成 | `wire ./...` 或 `go generate ./...` |
| 迁移创建 | `atlas migrate diff <name> ...` |

---

## 参考文档

遇到复杂场景时，查阅以下参考文档：

| 文档 | 内容 | 何时查阅 |
|------|------|---------|
| [entsqlite-driver.md](references/entsqlite-driver.md) | SQLite 驱动配置、连接参数、性能调优 | 配置数据库连接、解决并发问题 |
| [ent-schema.md](references/ent-schema.md) | Schema 定义、查询、关系、事务 | 设计数据模型、编写 CRUD |
| [atlas-migration.md](references/atlas-migration.md) | 迁移工具使用、SQLite 集成 | 版本化迁移、生产部署 |
| [embed-config.md](references/embed-config.md) | Go embed 配置、SPA 路由 | 前端嵌入、静态资源服务 |
| [framework-integration.md](references/framework-integration.md) | Echo v5 API、fx 集成、Handler 编写 | Web 框架配置、模块化架构 |

---

**记住**：
- ✅ 驱动名称 `"sqlite3"`（entsqlite）
- ✅ WAL 模式提升并发性能
- ✅ embed 嵌入前端实现单文件部署
- ✅ 无 CGO 支持任意平台交叉编译