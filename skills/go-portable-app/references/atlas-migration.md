# Atlas 迁移工具详解

> Ent 官方推荐的迁移工具，支持版本化迁移和 SQLite

**官方文档**: https://atlasgo.io/getting-started

---

## 安装

```bash
# macOS + Linux
curl -sSf https://atlasgo.sh | sh

# Homebrew
brew install ariga/tap/atlas

# Docker
docker pull arigaio/atlas
docker run --rm arigaio/atlas --help

# Go install
go install ariga.io/atlas/cmd/atlas@latest

# GitHub Actions
- uses: ariga/setup-atlas@v0
  with:
    cloud-token: ${{ secrets.ATLAS_CLOUD_TOKEN }}
```

---

## 为什么用 Atlas

| 工具 | 版本化迁移 | SQLite 支持 | Ent 集成 | 回滚 | 安全检查 |
|------|-----------|-------------|----------|------|----------|
| ent migrate | ❌ | ✅ | ✅ | ❌ | ❌ |
| golang-migrate | ✅ | ⚠️ | ❌ | ✅ | ❌ |
| **Atlas** | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 核心概念

### 声明式工作流 (Declarative)

定义期望的数据库 schema，Atlas 自动计算差异并应用：
- **schema.sql** 定义目标状态
- Atlas 对比当前状态和目标状态
- 自动生成并执行迁移计划

### 版本化工作流 (Versioned)

生成迁移文件，适合团队协作和 CI/CD：
- 编辑 schema 后运行 `atlas migrate diff`
- 生成 SQL 迁移文件（可提交到版本控制）
- 使用 `atlas migrate lint` 检查安全性
- 使用 `atlas migrate apply` 应用迁移

---

## 项目配置

### 目录结构

```
ent/
  ├── schema/           # Ent schema 定义
  └── migrate/
      └── migrations/   # Atlas 迁移文件
          ├── 20240101_initial.sql
          ├── 20240102_add_users.sql
          └── atlas.sum  # 校验文件
```

---

## SQLite 基本命令

### 创建迁移（SQLite）

```bash
atlas migrate diff create_users \
  --dir "file://ent/migrate/migrations" \
  --to "ent://ent/schema" \
  --dev-url "sqlite://file?mode=memory&_fk=1"
```

### 应用迁移（SQLite）

```bash
atlas migrate apply \
  --dir "file://ent/migrate/migrations" \
  --url "sqlite://file:./dev.db?_fk=1"
```

### 查看当前状态

```bash
atlas schema inspect \
  --url "sqlite://file:./dev.db?_fk=1" \
  --format '{{ sql . }}'
```

---

## Ent 集成

### 自动迁移（开发环境）

```go
// 简单方式：ent 自动迁移
client, err := ent.Open("sqlite3", dsn)
if err := client.Schema.Create(ctx); err != nil {
    return err
}
```

### 版本化迁移（生产环境）

```bash
# 从 Ent schema 生成迁移
atlas migrate diff initial \
  --dir "file://ent/migrate/migrations" \
  --to "ent://ent/schema" \
  --dev-url "sqlite://file?mode=memory&_fk=1"

# 应用迁移
atlas migrate apply \
  --dir "file://ent/migrate/migrations" \
  --url "sqlite://file:./prod.db?_fk=1"
```

---

## 迁移安全检查

Atlas 提供 lint 功能检查迁移安全性：

```bash
# 检查最近的迁移
atlas migrate lint \
  --dev-url "sqlite://dev?mode=memory" \
  --latest 1
```

常见检测项：
- 破坏性变更（删除表、删除列）
- 数据丢失风险
- 非最优列对齐（内存浪费）

---

## SQLite 特殊处理

### 启用外键

Atlas 默认不启用 SQLite 外键，需要显式配置：

```bash
atlas migrate apply \
  --url "sqlite://file:./dev.db?_fk=1"
```

### WAL 模式

迁移后手动启用 WAL：

```bash
sqlite3 dev.db "PRAGMA journal_mode=WAL;"
```

或在应用启动时启用：

```go
// 应用启动后执行
client, err := ent.Open("sqlite3", dsn)
// 启用 WAL 和其他优化
db.Exec("PRAGMA journal_mode=WAL;")
db.Exec("PRAGMA synchronous=NORMAL;")
```

---

## 迁移文件格式

```sql
-- 20240101_create_users.sql
-- atlas:sum h1:abc123...

CREATE TABLE users (
    id UUID PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_users_username ON users(username);
CREATE UNIQUE INDEX idx_users_email ON users(email);
```

`atlas.sum` 文件包含所有迁移文件的校验和，用于检测篡改。

---

## 可视化 Schema

```bash
# 打开 ERD 图
atlas schema inspect \
  --url "sqlite://file:./dev.db?_fk=1" \
  -w  # 在浏览器中打开
```

---

## CI/CD 集成

```yaml
# .github/workflows/migrate.yml
name: Database Migration

on:
  push:
    paths:
      - 'ent/schema/**'

jobs:
  migrate:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - uses: ariga/setup-atlas@v0
      
      - name: Generate migration
        run: |
          atlas migrate diff new_changes \
            --dir "file://ent/migrate/migrations" \
            --to "ent://ent/schema" \
            --dev-url "sqlite://file?mode=memory&_fk=1"
      
      - name: Lint migration
        run: |
          atlas migrate lint \
            --dev-url "sqlite://dev?mode=memory" \
            --latest 1
      
      - name: Apply migration
        run: |
          atlas migrate apply \
            --dir "file://ent/migrate/migrations" \
            --url "sqlite://file:./staging.db?_fk=1"
```

---

## 多数据库支持

Atlas 支持多种数据库：

| 数据库 | dev-url 示例 |
|--------|-------------|
| SQLite | `sqlite://file?mode=memory&_fk=1` |
| PostgreSQL | `docker://postgres/17/dev?search_path=public` |
| MySQL | `docker://mysql/8/dev` |
| MariaDB | `docker://mariadb/latest/test` |
| SQL Server | `docker://sqlserver/2022-latest/dev?mode=schema` |
| ClickHouse | `docker://clickhouse/23.11/dev` |

---

## 常见问题

### 迁移冲突

```
Error: migration file conflict
```

**解决**：
1. 检查 `atlas.sum` 校验
2. 使用 `atlas migrate hash` 重新生成

### SQLite 外键不生效

```
foreign key constraint failed
```

**解决**：添加 `_fk=1` 到 URL

### 回滚失败

```
Error: cannot down migrate
```

**解决**：确保迁移文件有 `-- atlas:sum` 校验行

---

## 推荐工作流

### 开发环境

```bash
# 1. 修改 ent schema
vim ent/schema/user.go

# 2. 生成迁移
atlas migrate diff add_user_fields \
  --dir "file://ent/migrate/migrations" \
  --to "ent://ent/schema" \
  --dev-url "sqlite://file?mode=memory&_fk=1"

# 3. 检查迁移安全性
atlas migrate lint \
  --dev-url "sqlite://dev?mode=memory" \
  --latest 1

# 4. 应用迁移
atlas migrate apply \
  --dir "file://ent/migrate/migrations" \
  --url "sqlite://file:./dev.db?_fk=1"

# 5. 验证
go test ./...
```

### 生产环境

```bash
# 1. 创建迁移（在开发环境）
atlas migrate diff prod_changes \
  --dir "file://ent/migrate/migrations" \
  --to "ent://ent/schema" \
  --dev-url "sqlite://file?mode=memory&_fk=1"

# 2. 提交迁移文件
git add ent/migrate/migrations/
git commit -m "chore: add database migration"

# 3. CI 中应用迁移
# （在部署前自动执行）
```

---

## 命令速查

| 操作 | 命令 |
|------|------|
| 创建迁移 | `atlas migrate diff <name> --dir ... --to ... --dev-url ...` |
| 应用迁移 | `atlas migrate apply --dir ... --url ...` |
| 检查迁移 | `atlas migrate lint --dev-url ... --latest 1` |
| 查看状态 | `atlas schema inspect --url ... --format '{{ sql . }}'` |
| 校验文件 | `atlas migrate hash --dir ...` |
| 可视化 | `atlas schema inspect --url ... -w` |
| 清理数据库 | `atlas schema clean --url ... --auto-approve` |

---

## 参考资料

- [Atlas Getting Started](https://atlasgo.io/getting-started)
- [Atlas Ent Integration](https://entgo.io/docs/versioned-migrations)
- [Atlas CLI Reference](https://atlasgo.io/cli)