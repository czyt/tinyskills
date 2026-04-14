---
name: lazycat-app-publisher
description: LazyCat v1.5.0+ app publisher with intelligent Docker Compose conversion, smart dependency analysis, auto-generated credentials, compose_override support, advanced routing (upstreams/ingress), file handlers, hardware acceleration, and complete publishing workflow. Default LPK v2 format with package.yml + lzc-manifest.yml separation. Triggers when converting Docker Compose to LazyCat format, publishing apps to LazyCat store, creating LPK packages, or managing LazyCat application lifecycle.
preferences:
  - id: add_root_to_public_path
    name: Add / to public_path
    description: Automatically add "/" to application.public_path in the generated manifest
    type: boolean
    default: true
  - id: manifest_multilingual
    name: Manifest Multilingual Support
    description: Generate locales with both English and Chinese in manifest files
    type: boolean
    default: true
  - id: simple_app_optimization
    name: Simple App Optimization
    description: Skip lzc-deploy-params.yml generation for simple applications
    type: boolean
    default: true
  - id: auto_healthcheck
    name: Auto Healthcheck
    description: Automatically add healthcheck configurations to services
    type: boolean
    default: true
  - id: auto_resource_limits
    name: Auto Resource Limits
    description: Automatically add reasonable resource limits to services
    type: boolean
    default: true
  - id: minimal_docs
    name: Minimal Documentation
    description: Generate only README.md with essential info, skip other markdown files
    type: boolean
    default: true
  - id: background_task
    name: Background Task Mode
    description: Set application.background_task to true by default for long-running background services
    type: boolean
    default: false
  - id: package_prefix
    name: Package Name Prefix
    description: Default package name prefix for applications (community.lazycat.app, cloud.lazycat.app, or custom)
    type: string
    default: cloud.lazycat.app
  - id: generate_compose_override
    name: Generate compose_override
    description: Generate compose_override section in lzc-build.yml for unsupported Docker Compose parameters
    type: boolean
    default: true
  - id: passwordless_login
    name: Passwordless Login Configuration
    description: Automatically configure passwordless login for apps with password systems using injects
    type: boolean
    default: true
---

# LazyCat App Publisher

This skill helps you convert Docker Compose files and Docker commands into LazyCat Cloud application configurations with **intelligent dependency analysis** and **automatic configuration optimization**.

## Reference Documents

| Document | Content |
|----------|---------|
| [references/strict-constraints.md](references/strict-constraints.md) | **严格约束 - 各配置文件允许/禁止字段** ⭐ |
| [references/passwordless-login.md](references/passwordless-login.md) | **免密登录配置 - 所有应用必备** ⭐ |
| [references/version-features.md](references/version-features.md) | OS版本与特性对照表 - min_os_version 设置 |
| [references/quick-reference.md](references/quick-reference.md) | 快速参考 - 常用转换规则和命令 |
| [references/healthcheck.md](references/healthcheck.md) | 健康检查配置 - v1.4.1+ 格式 |
| [references/manifest.md](references/manifest.md) | Manifest 完整格式规范 |
| [references/advanced-features.md](references/advanced-features.md) | 高级功能 - compose_override, 资源限制, 网络等 |
| [references/intelligent-analysis.md](references/intelligent-analysis.md) | 智能分析逻辑 - 服务分类, 参数优化 |
| [references/publish-workflow.md](references/publish-workflow.md) | 发布流程 - 镜像复制, 应用商店发布 |
| [references/dev-workflow.md](references/dev-workflow.md) | 开发工作流 - 前后端开发, 构建配置 |
| [references/injects.md](references/injects.md) | Script Injection - ctx API, 开发代理 |
| [references/cli-reference.md](references/cli-reference.md) | lzc-cli 命令参考 |
| [references/spec.md](references/spec.md) | 官方规范参考 |
| [references/docker-compose-examples.md](references/docker-compose-examples.md) | Docker Compose 转换示例 |
| [references/docker-run-examples.md](references/docker-run-examples.md) | Docker Run 转换示例 |
| [references/real-world-examples.md](references/real-world-examples.md) | 真实项目示例 |

---

## OS Version Requirements

**⚠️ LPK v2 格式强制要求：`min_os_version: 1.5.0`**

LPK v2（tar 格式，包含 `package.yml`）是 lzcos v1.5.0+ 才支持的特性。如果使用 LPK v2 格式，必须设置 `min_os_version: 1.5.0` 或更高版本。

| Feature | Minimum Version | Notes |
|---------|----------------|-------|
| **LPK v2 / `package.yml`** | **v1.5.0** | **强制要求！新项目默认使用** |
| `/lzcapp/documents` (新路径) | v1.5.0 | 替代旧路径 `/lzcapp/document` |
| `permissions` 声明 | v1.5.0 | 权限系统 |
| `services.[].healthcheck` | v1.4.1 | 100% docker-compose compatible |
| `compose_override` | v1.3.0 | For unsupported docker-compose params |
| `application.upstreams` | v1.3.8 | Recommended over `routes` |
| `services.[].mem_limit`, `shm_size` | v1.3.8 | Memory limits |
| `lzc-cli project` workflow | lzc-cli v2.0.0+ | Required for LPK v2 |

**版本决策表：**

| 格式/特性 | 设置 min_os_version |
|-----------|-------------------|
| LPK v2 (tar, package.yml) | **1.5.0** (强制) |
| LPK v1 (zip) | 无限制 |
| 使用 `/lzcapp/documents` | 1.5.0 |
| 使用 `permissions` | 1.5.0 |
| 使用 `upstreams`, `mem_limit` | 1.3.8 |

详见 [references/version-features.md](references/version-features.md) 和 [references/strict-constraints.md](references/strict-constraints.md)

---

## Quick Start

### Convert Docker Compose

```
Convert this docker-compose.yml to LazyCat app format:
[provide docker-compose.yml content or file path]
```

### Convert Docker Run

```
Convert this docker run command to LazyCat app:
docker run -d -p 8080:80 -e APP_ENV=production --name myapp nginx
```

### Publish to Store

```
Help me publish this application to LazyCat Cloud:
[provide docker-compose.yml]
```

---

## Intelligent Analysis Logic

### Service Classification

```python
def classify_service(service_config):
    has_healthcheck = 'healthcheck' in service_config
    has_external_ports = 'ports' in service_config

    # Internal service = has healthcheck + no external ports
    if has_healthcheck and not has_external_ports:
        return 'INTERNAL'  # Auto-configure
    else:
        return 'EXTERNAL'  # User-configured
```

| Service | Health Check | External Ports | Type | Configuration |
|---------|--------------|----------------|------|---------------|
| PostgreSQL | ✅ | ❌ | Internal | Auto-generated password |
| Redis | ✅ | ❌ | Internal | Auto-generated password |
| Web App | ❌ | ✅ | External | User-configured |

### Parameter Templates

| 场景 | 推荐函数 | 示例 |
|------|---------|------|
| 内部服务密码 | `{{.INTERNAL.xxx}}` | `{{.INTERNAL.db_password}}` |
| 用户必须配置 | `{{.U.xxx}}` | `{{.U.jwt_secret_key}}` |
| 稳定密钥 | `{{ stable_secret "seed"}}` | `{{ stable_secret "api_key"}}` |
| 运行时变量 | `${LAZYCAT_*}` | `${LAZYCAT_APP_ID}` |

详见 [references/intelligent-analysis.md](references/intelligent-analysis.md)

### Setup Wizard Constraints

生成 `lzc-deploy-params.yml` 时，**严格按照官方规范**：

#### 允许的字段（完整列表）

- ✅ `id` - 参数 ID（推荐小写英文+下划线）
- ✅ `type` - 仅支持 `bool`、`lzc_uid`、`string`、`secret`
- ✅ `name` - 参数名称（英文）
- ✅ `description` - 参数描述（英文）
- ✅ `optional` - 是否可选
- ✅ `default_value` - 默认值，支持 `$random(len=5)`
- ✅ `hidden` - 字段生效但不在界面中渲染

#### ❌ 禁止使用的字段

**以下字段不存在，禁止生成：**

- ❌ `placeholder` - 不存在
- ❌ `regex` - 不存在
- ❌ `regex_message` - 不存在
- ❌ `min` - 不存在
- ❌ `max` - 不存在
- ❌ `type: number` - 不支持
- ❌ `type: integer` - 不支持
- ❌ `type: email` - 不支持
- ❌ `type: url` - 不支持
- ❌ `required` - 应使用 `optional: false`
- ❌ `value` - 应使用 `default_value`

#### 约束输入的正确做法

需要约束输入格式时，在 `description` 中说明：

```yaml
# ✅ 正确做法
params:
  - id: port_number
    type: string  # 使用 string 类型
    name: "Port Number"
    description: "Service port number (1-65535, default 8080)"
    default_value: "8080"
```

详见 [references/strict-constraints.md](references/strict-constraints.md)

### Package Layout Constraints

生成应用文件时，**默认使用 LPK v2 格式**（需要 lzcos v1.5.0+ 和 lzc-cli v2.0.0+）：

#### lzc-build.yml 允许的字段

- ✅ `manifest` - manifest.yml 文件路径（必需）
- ✅ `pkgout` - LPK 输出路径（必需）
- ✅ `icon` - 应用图标路径（必需，512x512 PNG）
- ✅ `contentdir` - 内容目录（可选）
- ✅ `pkg_id` - 覆盖 package.yml.package（可选）
- ✅ `pkg_name` - 覆盖 package.yml.name（可选）
- ✅ `envs` - 构建期变量（可选，`KEY=VALUE` 数组）
- ✅ `buildscript` - 构建脚本（可选）
- ✅ `images` - 内嵌镜像构建（可选）
- ✅ `compose_override` - compose 覆盖（可选）

#### ❌ lzc-build.yml 禁止的字段

**以下字段应放在其他文件：**

- ❌ `package`, `version`, `name`, `description`, `min_os_version`, `locales`, `author`, `license`, `homepage` → 应在 `package.yml`
- ❌ `application`, `services`, `subdomain` → 应在 `lzc-manifest.yml`
- ❌ `dockerfile`, `context` → 应在 `images` 配置内部

#### LPK v2 默认布局（推荐）

```
.
├── lzc-build.yml          # 构建配置
├── lzc-build.dev.yml      # 开发态覆盖（可选）
├── package.yml            # 静态包元数据（LPK v2 必需）
├── lzc-manifest.yml       # 运行结构定义
└── icon.png               # 应用图标
```

**package.yml 必须包含**：
- `package` - 包 ID
- `version` - 版本
- `name`, `description` - 名称和描述
- `min_os_version: 1.5.0` - **LPK v2 格式强制要求**

**lzc-manifest.yml 只保留运行结构**：
- `application` - 应用配置
- `services` - 服务配置
- `ext_config` - 扩展配置
- `usage` - 使用说明

详见 [references/strict-constraints.md](references/strict-constraints.md)

---

## Docker → LazyCat Mapping

| Docker Feature | LazyCat Equivalent |
|----------------|-------------------|
| `ports` (HTTP) | `application.upstreams` ⭐ |
| `ports` (TCP/UDP) | `application.ingress` |
| `volumes` | `services.*.binds` |
| `environment` | `services.*.environment` |
| `depends_on` | `services.*.depends_on` |
| `command` | `services.*.command` (必须是字符串!) |
| `shm_size` | `services.*.shm_size` |

### Volume Path Mapping

- **Docker**: `/some/path:/container/path`
- **LazyCat**: `/lzcapp/var/...:/container/path` 或 `/lzcapp/cache/...:/container/path`

**文档路径变更（v1.5.0+）**：

| 版本 | 路径 | 说明 |
|------|------|------|
| v1.5.0+ | `/lzcapp/documents` | 新路径，推荐 |
| < v1.5.0 | `/lzcapp/document` | 废弃，仅兼容 |

需要文档访问权限时，需在 manifest 中声明：
```yaml
ext_config:
  enable_document_access: true
```

详见 [references/quick-reference.md](references/quick-reference.md)

---

## Passwordless Login Configuration

**⚠️ 重要：所有自带密码体系的应用都必须配置免密登录！**

LazyCat 微服要求应用提供良好的用户体验，用户不应该每次都手动输入密码。

### 三种常用方案

#### 方案一：部署参数 + simple-inject-password（简单场景）

适用于登录账号固定或由部署参数提供的场景：

```yaml
# lzc-deploy-params.yml
params:
  - id: login_user
    type: string
    name: "Login User"
    description: "Default login username"
    default_value: "admin"

  - id: login_password
    type: secret
    name: "Login Password"
    description: "Default login password"
    default_value: "$random(len=20)"

# lzc-manifest.yml
application:
  injects:
    - id: login-autofill
      when:
        - /login
        - /signin
      do:
        - src: builtin://simple-inject-password
          params:
            user: "{{ index .U \"login_user\" }}"
            password: "{{ index .U \"login_password\" }}"
```

#### 方案二：三阶段联动（高级场景）

适用于用户首次创建账号、后续可能修改密码的场景：

```yaml
# request 阶段：捕获用户名/密码
injects:
  - id: capture-password
    on: request
    when:
      - /api/login
      - /api/setup
    do: |
      const payload = ctx.body.getJSON();
      ctx.flow.set("pending_user", payload.username);
      ctx.flow.set("pending_pass", payload.password);

# response 阶段：成功后持久化
  - id: commit-password
    on: response
    when:
      - /api/login
      - /api/setup
    do: |
      if (ctx.status >= 200 && ctx.status < 300) {
        ctx.persist.set("saved_user", ctx.flow.get("pending_user"));
        ctx.persist.set("saved_pass", ctx.flow.get("pending_pass"));
      }

# browser 阶段：自动填充
  - id: autofill-login
    when:
      - /login
    do:
      - src: builtin://simple-inject-password
        params:
          user:
            $persist: saved_user
          password:
            $persist: saved_pass
```

#### 方案三：Basic Auth Header 注入

适用于上游服务使用 Basic Auth 的场景：

```yaml
application:
  injects:
    - id: inject-basic-auth
      on: request
      auth_required: false
      when:
        - /api/*
      do: |
        ctx.headers.set("Authorization", "Basic " + ctx.base64.encode("admin:password"));
```

### 关键注意事项

1. **`on: request/response` 不能使用 hash 规则**（如 `/#login`）
2. **request 阶段不要直接写入 `persist`**，先存入 `flow`，response 成功后再持久化
3. **显式指定选择器**，确保特殊命名页面也能正确填充

详见 [references/passwordless-login.md](references/passwordless-login.md)

---

## Best Practices

### ✅ Do - LPK v2 完整示例（推荐，lzcos v1.5.0+）

**⚠️ 重要：LPK v2 格式必须设置 `min_os_version: 1.5.0`**

```yaml
# package.yml - 静态元数据
package: cloud.lazycat.app.myapp
version: 1.0.0
name: MyApp
description: "My application"
min_os_version: 1.5.0  # ✅ LPK v2 强制要求
author: "Developer"
license: MIT
homepage: https://example.com

locales:
  zh:
    name: "我的应用"
    description: "我的应用描述"
  en:
    name: "My App"
    description: "My application"

permissions:
  required:
    - net.internet
  optional:
    - document.read
```

```yaml
# lzc-manifest.yml - 运行结构（不包含静态元数据）
application:
  subdomain: myapp
  upstreams:  # ✅ 推荐使用 upstreams 替代 routes
    - location: /
      backend: http://myapp:8080/
  injects:  # ✅ 免密登录配置
    - id: login-autofill
      when:
        - /login
      do:
        - src: builtin://simple-inject-password
          params:
            user: "{{ index .U \"login_user\" }}"
            password: "{{ index .U \"login_password\" }}"

services:
  postgres:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD={{.INTERNAL.db_password}}
    healthcheck:  # ✅ v1.4.1: 使用 'healthcheck' (无下划线)
      test:
        - CMD-SHELL
        - pg_isready -U postgres
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    binds:
      - /lzcapp/var/db:/var/lib/postgresql/data
```

```yaml
# lzc-build.yml - 构建配置（只包含构建相关字段）
manifest: ./lzc-manifest.yml
pkgout: ./
icon: ./icon.png
# ✅ 不包含 package, version, name 等静态元数据
```

```yaml
# lzc-deploy-params.yml - 部署参数（严格按规范）
params:
  - id: login_user  # ✅ 小写英文+下划线
    type: string  # ✅ 只使用 string/secret/bool/lzc_uid
    name: "Login User"
    description: "Default login username"
    default_value: "admin"
    optional: true

  - id: login_password
    type: secret
    name: "Login Password"
    description: "Default login password"
    default_value: "$random(len=20)"
    optional: true

locales:
  zh:
    login_user:
      name: "登录用户"
      description: "默认登录用户名"
    login_password:
      name: "登录密码"
      description: "默认登录密码"
```

### ❌ Avoid - Common Mistakes

```yaml
# ❌ 将静态包元数据放在 lzc-manifest.yml（LPK v2 不允许）
# 这些字段应该移到 package.yml
package: cloud.lazycat.app.myapp
version: 1.0.0
name: MyApp

# ❌ LPK v2 格式 min_os_version 设置过低
min_os_version: 1.3.8  # ❌ LPK v2 必须是 1.5.0
# ✅ 正确：min_os_version: 1.5.0

# ❌ lzc-build.yml 包含不存在的字段
package: myapp  # ❌ 应在 package.yml
version: 1.0.0  # ❌ 应在 package.yml
subdomain: myapp  # ❌ 应在 lzc-manifest.yml

# ❌ lzc-deploy-params.yml 包含不存在的字段
params:
  - id: port
    type: number  # ❌ 不支持 number 类型
    min: 1  # ❌ 不存在 min 字段
    max: 65535  # ❌ 不存在 max 字段
    placeholder: "8080"  # ❌ 不存在 placeholder 字段
    regex: "^[0-9]+$"  # ❌ 不存在 regex 字段

# ❌ 旧格式 lzc-sdk-version
lzc-sdk-version: "0.1"  # 已移除！

# ❌ 对 services 使用废弃的 health_check
services:
  postgres:
    health_check:  # 已废弃！使用 'healthcheck'

# ❌ 使用 routes 而不是 upstreams
application:
  routes:
    - /=http://myapp:8080/  # 使用 upstreams 替代

# ❌ admin_only 不能与非空 public_path 同时存在
admin_only: true
application:
  public_path:
    - /

# ❌ 硬编码密钥
environment:
  - PASSWORD=secret123  # 使用 {{.U.password}} 或 {{.INTERNAL.xxx}}

# ❌ v1.5.0+ 使用旧文档路径
binds:
  - /lzcapp/document:/data  # 使用 /lzcapp/documents

# ❌ command 使用数组而非字符串
services:
  redis:
    command: ["redis-server", "--requirepass", "mypass"]  # ❌
    # ✅ 正确：command: redis-server --requirepass mypass

# ❌ 缺少免密登录配置（密码体系应用必须有）
application:
  subdomain: myapp
  # 缺少 injects 配置，用户每次都要手动输入密码
```

---

## Development Workflow

### 环境要求

**LPK v2 格式（默认，推荐）**：
- lzcos v1.5.0+
- lzc-cli v2.0.0+ (`npm install -g @lazycatcloud/lzc-cli@2.0.0`)

**安装 CLI**：
```bash
npm install -g @lazycatcloud/lzc-cli
# 或指定 v2 版本
npm install -g @lazycatcloud/lzc-cli@2.0.0
```

### Quick Decision Table

| Your Goal | Use This |
|-----------|----------|
| Change UI with hot reload | `project deploy` + `npm run dev` |
| Change backend code | `project deploy` + `project sync --watch` + `project exec` |
| Build package for others | `project release` |

### Key Commands

```bash
# Create project from template
lzc-cli project create myapp -t hello-vue

# Deploy (uses lzc-build.dev.yml if exists, else lzc-build.yml)
lzc-cli project deploy

# Deploy with release config
lzc-cli project deploy --release

# Sync code (watch mode)
lzc-cli project sync --watch

# Enter container
lzc-cli project exec /bin/sh

# View logs
lzc-cli project log -f

# Build release package (LPK v2 by default with lzc-cli v2.0.0+)
lzc-cli project release -o app.lpk

# Check LPK info
lzc-cli lpk info app.lpk

# Publish to store
lzc-cli appstore publish app.lpk
```

详见 [references/dev-workflow.md](references/dev-workflow.md) 和 [references/cli-reference.md](references/cli-reference.md)

---

## LPK v1 to v2 Migration

### Using the Converter Script

A Python script is provided to convert existing LPK v1 packages to v2 format:

```bash
# Basic usage
python scripts/lpk_v1_to_v2.py app.lpk

# Specify output
python scripts/lpk_v1_to_v2.py app.lpk new-app.lpk

# Output to directory
python scripts/lpk_v1_to_v2.py app.lpk ./output/
```

**What the converter does:**
1. Extracts LPK v1 (zip format)
2. Splits `manifest.yml` into:
   - `package.yml` - static metadata (package, version, name, description, etc.)
   - `manifest.yml` - runtime structure (application, services, ext_config)
3. Repackages as LPK v2 (tar format)

**Requirements:**
```bash
pip install pyyaml
```

### Manual Migration

For simple cases, you can manually migrate:

```bash
# 1. Extract v1
unzip app.lpk -d temp/

# 2. Create package.yml from manifest.yml static fields
cat > package.yml << 'EOF'
package: your.app.id
version: 1.0.0
name: Your App
description: App description
min_os_version: 1.3.8
EOF

# 3. Remove static fields from manifest.yml (keep only application, services, ext_config, usage)

# 4. Repack as v2
tar -cf app-v2.lpk package.yml manifest.yml content.tar.gz META/
```

---

`injects` allows you to inject scripts into browser, request, or response phases.

| Phase | Runtime | Use Case |
|-------|---------|----------|
| `on=browser` | Browser | DOM manipulation, autofill |
| `on=request` | lzcinit | Header injection, routing |
| `on=response` | lzcinit | CORS/CSP modification |

```yaml
application:
  injects:
    - id: dev-proxy
      on: request
      auth_required: false
      when:
        - "/*"
      do:
        - src: |
            if (ctx.dev.id && ctx.net.reachable("tcp", "127.0.0.1", 3000, ctx.net.via.client(ctx.dev.id))) {
              ctx.proxy.to("http://127.0.0.1:3000", {
                via: ctx.net.via.client(ctx.dev.id),
                use_target_host: true,
              });
            }
```

详见 [references/injects.md](references/injects.md)

---

## Critical Rules

### 🚨 TOP 5 CRITICAL RULES

#### ❌ Rule 1: DO NOT Auto-Add Healthcheck
如果原始 docker-compose.yml 没有 healthcheck，不要自动添加。容器可能缺少 curl/wget 工具。

#### ❌ Rule 2: binds Only Supports Directories, Not Files
使用 contentdir + setup_script 替代文件挂载：
```yaml
# lzc-build.yml
contentdir: ./content

# lzc-manifest.yml
services:
  web:
    setup_script: |
      cp /lzcapp/pkg/content/nginx.conf /etc/nginx/nginx.conf
```

#### ❌ Rule 3: LPK v2 MUST Set min_os_version: 1.5.0
LPK v2 格式（tar + package.yml）是 v1.5.0+ 才支持的特性：
```yaml
# package.yml
package: cloud.lazycat.app.myapp
version: 1.0.0
min_os_version: 1.5.0  # ✅ 必须设置
```

#### ❌ Rule 4: DO NOT Generate Invalid Fields
严格按官方规范生成配置文件，禁止生成不存在的字段：
- lzc-build.yml: 禁止 `package`, `version`, `name`, `subdomain` 等
- lzc-deploy-params.yml: 禁止 `placeholder`, `regex`, `min`, `max`, `type: number`

#### ❌ Rule 5: All Password Apps MUST Have Passwordless Config
如果应用自带密码体系，必须配置免密登录：
- 使用 `simple-inject-password` 自动填充
- 或使用三阶段联动记录用户修改的密码

---

## App Store Check (Automatic)

每当用户请求转换或创建应用时，技能会**自动**检查懒猫应用商店中是否已存在同名应用：

```bash
# Search API
GET https://search.lazycat.cloud/api/v1/app?keyword={app_name}&size=48
```

如果找到匹配应用，会提示用户是否继续创建。

---

## Preferences

| Preference | Default | Description |
|------------|---------|-------------|
| Add / to public_path | true | 自动添加 "/" 到 public_path |
| Manifest Multilingual | true | 生成中英文 locales |
| Simple App Optimization | true | 简单应用跳过 params 生成 |
| Auto Healthcheck | true | 自动添加 healthcheck |
| Auto Resource Limits | true | 自动添加资源限制 |
| Minimal Documentation | true | 只生成 README.md |
| Background Task | false | 设置 background_task: true |
| Package Prefix | cloud.lazycat.app | 包名前缀 |
| Generate compose_override | true | 生成 compose_override |
| Passwordless Login | true | **为密码体系应用自动配置免密登录** |

---

## Examples

### Example 1: Simple Web App

**Input (docker-compose.yml):**
```yaml
services:
  postgres:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]

  app:
    image: myapp:latest
    environment:
      - DATABASE_URL=postgresql://postgres:${DB_PASSWORD}@postgres:5432/app
      - SECRET_KEY=${SECRET_KEY}
    depends_on:
      - postgres
    ports:
      - "3000:3000"
```

**Output (Smart):**
```yaml
services:
  postgres:
    environment:
      - POSTGRES_PASSWORD={{.INTERNAL.db_password}}  # Auto
    healthcheck: {...}

  app:
    environment:
      - DATABASE_URL=postgresql://postgres:{{.INTERNAL.db_password}}@postgres:5432/app
      - SECRET_KEY={{.U.secret_key}}  # User
```

更多示例见 [references/docker-compose-examples.md](references/docker-compose-examples.md) 和 [references/real-world-examples.md](references/real-world-examples.md)

---

## References

- **Official Docs**: https://developer.lazycat.cloud
- **Documentation Repository**: https://gitee.com/lazycatcloud/lzc-developer-doc
- **App Store**: https://gitee.com/lazycatcloud/appdb
