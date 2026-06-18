---
name: justfile
description: Just 命令运行器助手 - 编写、调试和优化 justfile。支持配方(recipe)编写、变量定义、条件表达式、函数使用、跨平台兼容、并行任务、错误处理等。触发词：写 justfile、创建配方、just 命令、任务运行器、项目命令管理、just 语法。
---

# Just 命令运行器助手

帮助编写、调试和优化 justfile，让项目命令管理更简单高效。

## Reference Documents

| Document | Content |
|----------|---------|
| [references/just-man-zh-full.md](references/just-man-zh-full.md) | 📖 Just 用户指南完整中文版 |

---

## 快速开始

### 基本 justfile 结构

```just
# 注释：设置默认配方
default:
    @just --list

# 简单配方
hello:
    echo "Hello, World!"

# 带参数的配方
greet name:
    echo "Hello, {{name}}!"
```

### 运行配方

```bash
just hello          # 运行 hello 配方
just greet "World"  # 运行带参数的配方
just --list         # 列出所有配方
just                # 运行默认配方
```

---

## 核心语法

### 1. 变量定义

```just
# 简单变量
version := "1.0.0"

# 多行变量
files := """
  src/main.rs
  src/lib.rs
  tests/test.rs
"""

# 环境变量
home_dir := env('HOME')

# 条件变量
os := if os() == "linux" { "debian" } else { "unknown" }
```

### 2. 配方(recipe)基础

```just
# 静默配方（不显示命令）
@hello:
    echo "Hello!"

# 多行命令
build:
    cargo build
    cargo test
    echo "Done!"

# Shebang 配方（用其他语言）
python:
    #!/usr/bin/env python3
    print("Hello from Python")
```

### 3. 参数

```just
# 位置参数
greet name:
    echo "Hello, {{name}}!"

# 默认参数值
greet name="World":
    echo "Hello, {{name}}!"

# 可变参数
*files:
    echo "Files: {{files}}"

# 必需参数（无默认值）
deploy env version:
    echo "Deploying {{version}} to {{env}}"
```

### 4. 条件表达式

```just
# if-else
check:
    if [ -f "Cargo.toml" ]; then \
        echo "Rust project"; \
    else \
        echo "Not a Rust project"; \
    fi

# 变量条件
os := if os() == "macos" { "darwin" } else if os() == "linux" { "linux" } else { "unknown" }
```

### 5. 函数

```just
# 字符串函数
path := join("src", "main.rs")
ext := extension("file.txt")        # "txt"
base := file_stem("file.txt")       # "file"
name := file_name("path/file.txt")  # "file.txt"
dir := directory("path/file.txt")   # "path"

# 路径操作
abs := path_exists("Cargo.toml")    # true/false
```

---

## 常用模式

### 1. 项目初始化

```just
# 初始化项目结构
init:
    mkdir -p src tests docs
    touch src/main.rs
    echo "# Project" > README.md

# 从模板初始化
init-template name:
    mkdir -p {{name}}/src
    cp template/Cargo.toml {{name}}/
```

### 2. 构建系统

```just
# Rust 项目
build:
    cargo build --release

test:
    cargo test

lint:
    cargo clippy -- -D warnings
    cargo fmt --check

clean:
    cargo clean

# 一键检查
check: lint test build
    echo "All checks passed!"
```

### 3. Docker 操作

```just
# Docker 构建
docker-build tag="latest":
    docker build -t myapp:{{tag}} .

docker-run:
    docker run -p 8080:8080 myapp

docker-push tag="latest":
    docker push myapp:{{tag}}
```

### 4. 部署流程

```just
# 环境配置
env := env_var_or("ENV", "dev")
version := `git describe --tags --always`

# 部署到不同环境
deploy-staging:
    echo "Deploying {{version}} to staging..."
    kubectl apply -f k8s/staging/

deploy-prod:
    echo "Deploying {{version}} to production..."
    kubectl apply -f k8s/production/
```

### 5. 并行任务

```just
# 并行运行测试
test-all:
    just test-unit &
    just test-integration &
    wait
    echo "All tests complete!"

# 使用 xargs 并行处理
process-files:
    find . -name "*.txt" | xargs -P 4 -I {} process-file {}
```

---

## 高级特性

### 1. 私有配方

```just
# 以下划线开头的配方不会在 --list 中显示
_private-setup:
    echo "Setting up..."

# 调用私有配方
deploy:
    just _private-setup
    echo "Deploying..."
```

### 2. 模块化

```just
# 导入其他 justfile
import 'common.just'
import 'deploy.just'

# 或使用 mod（just 1.19+）
mod docker 'docker.just'
```

### 3. 错误处理

```just
# 忽略错误
test:
    -cargo test || echo "Tests failed, continuing..."

# 设置 shell
set shell := ["bash", "-euo", "pipefail"]

# 错误检查
check:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v cargo &> /dev/null; then
        echo "cargo not found"
        exit 1
    fi
```

### 4. 跨平台兼容

```just
# 检测操作系统
clean:
    if [ "{{os()}}" = "windows" ]; then \
        del /q /s build; \
    else \
        rm -rf build; \
    fi

# 使用平台特定命令
open-browser url:
    if [ "{{os()}}" = "macos" ]; then \
        open {{url}}; \
    elif [ "{{os()}}" = "linux" ]; then \
        xdg-open {{url}}; \
    fi
```

### 5. 文档注释

```just
# 显示帮助信息
help:
    @just --list

# 带文档的配方
# 构建项目 release 版本
build-release:
    cargo build --release

# 运行所有测试
# 可选参数: FILTER - 测试名称过滤器
test-all *FILTER:
    cargo test {{FILTER}}
```

---

## 最佳实践

### 0. 关键决策检查点

🔴 **CHECKPOINT · 部署到生产环境前必须确认：**
- 版本号是否正确？
- 是否在正确的分支上？
- 测试是否全部通过？
- 是否有备份/回滚方案？

```just
# 带确认的部署配方
deploy-prod version:
    #!/usr/bin/env bash
    echo "⚠️  You are about to deploy {{version}} to PRODUCTION"
    read -p "Are you sure? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Deployment cancelled"
        exit 0
    fi
    kubectl apply -f k8s/production/
```

### 1. 组织结构

```just
# ==================== 配置 ====================
project := "myapp"
version := `git describe --tags --always`

# ==================== 构建 ====================
build:
    cargo build

# ==================== 测试 ====================
test:
    cargo test

# ==================== 部署 ====================
deploy env:
    echo "Deploying to {{env}}"

# ==================== 工具 ====================
clean:
    cargo clean
```

### 2. 命名规范

- 使用 `kebab-case` 命名配方：`build-release`, `test-all`
- 私有配方用下划线：`_setup`, `_validate`
- 常用配方放在前面：`build`, `test`, `clean`

### 3. 默认配方

```just
# 设置默认配方
default:
    @just --list

# 或使用别名
alias l := list
list:
    @just --list
```

### 4. 环境变量管理

```just
# 从 .env 文件加载
set dotenv-load

# 使用环境变量，带默认值
db_url := env_var_or("DATABASE_URL", "sqlite://db.sqlite")

# 必需的环境变量
api_key := env("API_KEY")
```

### 5. 并行执行

```just
# 并行运行独立任务
ci: lint test build
    echo "CI complete!"

# 使用后台任务
watch:
    cargo watch -x test &
    cargo watch -x build &
    wait
```

---

## 失败模式与错误处理

### 显式失败分支（if-then 三段式）

```just
# 部署配方 - 完整失败处理
deploy env version:
    #!/usr/bin/env bash
    set -euo pipefail

    # 一线检查：环境参数验证
    if [[ "{{env}}" != "staging" && "{{env}}" != "production" ]]; then
        echo "❌ Error: env must be 'staging' or 'production', got '{{env}}'"
        exit 1
    fi

    # 一线检查：版本格式验证
    if [[ ! "{{version}}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "❌ Error: version must match vX.Y.Z format, got '{{version}}'"
        exit 1
    fi

    # 执行部署
    echo "🚀 Deploying {{version}} to {{env}}..."
    kubectl apply -f k8s/{{env}}/ 2>&1 || {
        # 仍失败兜底：记录错误并退出
        echo "❌ Deployment failed for {{version}} to {{env}}"
        echo "Check: kubectl get pods -n {{env}}"
        exit 1
    }

    echo "✅ Deployed {{version}} to {{env}} successfully"
```

### 常见失败场景对照表

| 场景 | 触发条件 | 一线修复 | 仍失败兜底 |
|------|---------|---------|-----------|
| 命令不存在 | `command -v X` 失败 | 提示安装命令 | 退出并报错 |
| 依赖缺失 | `cargo check` 失败 | 提示 `cargo install` | 退出并报错 |
| 网络超时 | curl/wget 超时 | 重试3次，间隔5秒 | 退出并报错 |
| 权限不足 | 命令返回非0 | 提示 sudo 或 chmod | 退出并报错 |
| 参数无效 | 正则匹配失败 | 提示正确格式 | 退出并报错 |

### 忽略非关键错误

```just
# 行首 `-` 忽略该行错误
test:
    -cargo test || echo "Tests had failures, continuing..."

# 块级忽略
cleanup:
    #!/usr/bin/env bash
    rm -rf build/ 2>/dev/null || true
    rm -f /tmp/just-*.tmp 2>/dev/null || true
    echo "Cleanup done (some files may not exist)"
```

---

## 反例与黑名单（不要做什么）

### ❌ 红灯：危险操作

| # | 反模式 | 为什么不要做 | 正确做法 |
|---|--------|-------------|---------|
| 1 | **直接 rm -rf /** | 误删系统文件，不可恢复 | 使用相对路径，加 `-i` 确认 |
| 2 | **硬编码密码/token** | 泄露到 git 历史 | 用 `env('SECRET')` 读环境变量 |
| 3 | **无参数验证的 deploy** | 部署到错误环境 | 添加 `_validate-env` 私有配方 |
| 4 | **忽略错误的构建** | 部署损坏的产物 | 使用 `set -euo pipefail` |
| 5 | **并行写同一文件** | 数据竞争，文件损坏 | 使用锁或顺序执行 |

### ⚠️ 黄灯：常见陷阱

| # | 反模式 | 问题 | 替代方案 |
|---|--------|------|---------|
| 1 | 配方名用 camelCase | 与 just 惯例不符 | 用 `kebab-case` |
| 2 | 过多公共配方 | `--list` 输出混乱 | 私有配方用 `_` 前缀 |
| 3 | 重复代码 | 维护困难 | 提取为私有配方复用 |
| 4 | 无默认配方 | 用户不知如何开始 | 设置 `default` 显示 `--list` |
| 5 | 忘记 `set shell` | 跨平台兼容问题 | 明确指定 shell 或用 shebang |

### 🔍 调试配方失败检查清单

```bash
# 1. 先干运行，看命令是否正确
just --dry-run build

# 2. 开启详细输出
just --verbose build

# 3. 检查变量值
just --evaluate

# 4. 单独运行失败的命令
cargo build  # 直接运行看报错

# 5. 检查 shell 版本
bash --version
```

---

## 常见问题

### Q: just 和 make 有什么区别？

just 是一个命令运行器，不是构建系统：
- 不需要 `.PHONY` 声明
- 错误信息更友好
- 跨平台支持更好
- 语法更简洁

### Q: 如何在子目录中使用 justfile？

```bash
# 在项目根目录运行子目录的 justfile
just -f subdir/justfile build

# 或在子目录中自动查找
cd subdir && just build
```

### Q: 如何调试 justfile？

```bash
# 显示执行的命令
just --verbose build

# 干运行（不执行）
just --dry-run build

# 显示变量值
just --evaluate
```

### Q: 如何处理包含空格的参数？

```just
# 使用引号
greet name:
    echo "Hello, {{name}}!"

# 调用时
# just greet "John Doe"
```

### Q: 如何复用配方？

```just
# 调用其他配方
test-all:
    just test-unit
    just test-integration
    just test-e2e

# 使用变量
test-suite suite:
    cargo test --test {{suite}}
```

---

## 实用示例

### Rust 项目模板

```just
# Rust 项目 justfile
project := "myapp"
version := `git describe --tags --always`

# 默认显示帮助
default:
    @just --list

# 构建
build:
    cargo build

# 构建 release
release:
    cargo build --release

# 测试
test:
    cargo test

# 代码检查
lint:
    cargo clippy -- -D warnings
    cargo fmt --check

# 格式化代码
fmt:
    cargo fmt

# 清理构建产物
clean:
    cargo clean

# 运行
run *args:
    cargo run -- {{args}}

# 生成文档
doc:
    cargo doc --open

# 发布前检查
pre-publish: lint test
    echo "Ready to publish!"

# 发布到 crates.io
publish: pre-publish
    cargo publish

# 所有检查
all: lint test build doc
    echo "All checks passed!"
```

### Node.js 项目模板

```just
# Node.js 项目 justfile
project := "myapp"
node := "node"
npm := "npm"

default:
    @just --list

# 安装依赖
install:
    {{npm}} install

# 构建
build:
    {{npm}} run build

# 测试
test:
    {{npm}} test

# 开发模式
dev:
    {{npm}} run dev

# 代码检查
lint:
    {{npm}} run lint

# 格式化
fmt:
    {{npm}} run format

# 清理
clean:
    rm -rf node_modules dist

# 发布
publish: lint test build
    {{npm}} publish

# Docker 构建
docker-build:
    docker build -t {{project}} .

# Docker 运行
docker-run:
    docker run -p 3000:3000 {{project}}
```

---

## 快速参考

| 命令 | 说明 |
|------|------|
| `just` | 运行默认配方 |
| `just RECIPE` | 运行指定配方 |
| `just --list` | 列出所有配方 |
| `just --summary` | 列出配方名称 |
| `just --evaluate` | 评估并显示变量 |
| `just --dry-run` | 干运行，显示命令但不执行 |
| `just --verbose` | 显示详细执行信息 |
| `just VAR=value` | 设置变量值 |
| `just -f FILE` | 使用指定的 justfile |
| `just -d DIR` | 在指定目录运行 |

## 语法速查

```just
# 变量
name := "value"
name := `command`
name := env('VAR')
name := env_var_or('VAR', 'default')

# 条件
x := if condition { "a" } else { "b" }

# 函数
join(a, b)
path_exists(p)
env('VAR')
arch()
os()

# 配方
recipe:
    command

recipe arg:
    command {{arg}}

recipe arg="default":
    command {{arg}}

# 属性
[no-cd]
[no-exit-message]
[private]
[confirm]
[group('name')]
[script]
[script('bash')]
```

---

## 更多信息

- 📖 [完整中文文档](references/just-man-zh-full.md)
- 🔗 [Just 官方网站](https://just.systems)
- 📦 [GitHub 仓库](https://github.com/casey/just)
- 💬 [Discord 社区](https://discord.gg/ezYScXR)
