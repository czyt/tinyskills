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
---

# LazyCat App Publisher

This skill helps you convert Docker Compose files and Docker commands into LazyCat Cloud application configurations with **intelligent dependency analysis** and **automatic configuration optimization**.

## Reference Documents

| Document | Content |
|----------|---------|
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

**推荐设置 `min_os_version: 1.3.8`** - 这是现代应用的推荐最低版本。

| Feature | Minimum Version |
|---------|----------------|
| `services.[].healthcheck` | v1.4.1 |
| `compose_override` | v1.3.0 |
| `application.upstreams` | v1.3.8 |
| `services.[].mem_limit`, `shm_size` | v1.3.8 |
| `/lzcapp/documents` (新路径) | v1.5.0 |
| LPK v2 / `package.yml` | v1.5.0 |
| `lzc-cli project` workflow | lzc-cli v2.0.0+ |

详见 [references/version-features.md](references/version-features.md)

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

生成 `lzc-deploy-params.yml` 时，严格按官方 `deploy-params` 规范输出：

- 仅使用字段：`id`、`type`、`name`、`description`、`optional`、`default_value`、`hidden`
- 仅使用类型：`bool`、`lzc_uid`、`string`、`secret`
- 不要生成 `placeholder`、`regex`、`regex_message`、`min`、`max`
- 不要生成 `type: number`
- 需要约束输入格式时，在 `description` 中说明；敏感值优先使用 `secret`

### Package Layout Constraints

生成应用文件时，**默认使用 LPK v2 格式**（推荐 lzcos v1.5.0+ 配合 lzc-cli v2.0.0+）：

**LPK v2 默认布局（推荐）**：
- 必须包含 `package.yml` - 静态包元数据：`package`、`version`、`name`、`description`、`locales`、`author`、`license`、`homepage`、`min_os_version`、`unsupported_platforms`、`admin_only`、`permissions`
- `lzc-manifest.yml` 只保留运行结构字段：`application`、`services`、`ext_config`、`usage`
- `lzc-build.yml` 支持 `pkg_id`、`pkg_name` 覆盖最终打包值
- 可选 `images/` 和 `images.lock` 用于内嵌镜像分发

**文件组织**：
```
.
├── lzc-build.yml          # 构建配置
├── lzc-build.dev.yml      # 开发态覆盖（可选）
├── package.yml            # 静态包元数据（LPK v2 必需）
├── lzc-manifest.yml       # 运行结构定义
└── icon.png               # 应用图标
```

**兼容性说明**：
- LPK v2 (tar 格式) 是 1.5.0+ 的默认格式，需要 `package.yml`
- LPK v1 (zip 格式) 仍兼容旧布局，但新项目应使用 v2
- 若目标系统低于 lzcos v1.5.0，可考虑继续使用 v1 格式

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

## Best Practices

### ✅ Do - LPK v2 完整示例（推荐，lzcos v1.5.0+）

```yaml
# package.yml - 静态元数据
package: cloud.lazycat.app.myapp
version: 1.0.0
name: MyApp
description: "My application"
min_os_version: 1.3.8
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
# lzc-manifest.yml - 运行结构
application:
  subdomain: myapp
  upstreams:  # ✅ 推荐使用 upstreams 替代 routes
    - location: /
      backend: http://myapp:8080/

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

### ❌ Avoid - Common Mistakes

```yaml
# ❌ 将静态包元数据放在 lzc-manifest.yml（LPK v2 不允许）
# 这些字段应该移到 package.yml
package: cloud.lazycat.app.myapp
version: 1.0.0
name: MyApp

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

### 🚨 TOP 2 CRITICAL RULES

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
