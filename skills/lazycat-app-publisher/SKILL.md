---
name: lazycat-app-publisher
description: LazyCat v1.4.1+ app publisher with intelligent Docker Compose conversion, smart dependency analysis, auto-generated credentials, compose_override support, advanced routing (upstreams/ingress), file handlers, hardware acceleration, and complete publishing workflow. Triggers when converting Docker Compose to LazyCat format, publishing apps to LazyCat store, creating LPK packages, or managing LazyCat application lifecycle.
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

详见 [references/quick-reference.md](references/quick-reference.md)

---

## Best Practices

### ✅ Do - Complete Manifest Structure (v1.4.1+)

```yaml
name: MyApp
package: cloud.lazycat.app.myapp
version: 1.0.0
min_os_version: 1.3.8  # Required for modern apps

application:
  subdomain: myapp
  upstreams:  # ✅ Recommended over routes
    - location: /
      backend: http://myapp:8080/

services:
  postgres:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD={{.INTERNAL.db_password}}
    healthcheck:  # ✅ v1.4.1: Use 'healthcheck' (no underscore)
      test:
        - CMD-SHELL
        - pg_isready -U postgres
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    binds:
      - /lzcapp/var/db:/var/lib/postgresql/data

locales:
  zh:
    name: "我的应用"
```

### ❌ Avoid - Common Mistakes

```yaml
# ❌ Old format with lzc-sdk-version
lzc-sdk-version: "0.1"  # Removed!

# ❌ Using deprecated health_check for services
services:
  postgres:
    health_check:  # Deprecated! Use 'healthcheck'

# ❌ Using routes instead of upstreams
application:
  routes:
    - /=http://myapp:8080/  # Use upstreams instead

# ❌ Hardcoding secrets
environment:
  - PASSWORD=secret123  # Use {{.U.password}} or {{.INTERNAL.xxx}}
```

---

## Development Workflow

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

# Deploy
lzc-cli project deploy

# Sync code (watch mode)
lzc-cli project sync --watch

# Enter container
lzc-cli project exec /bin/sh

# Build release package
lzc-cli project release -o app.lpk

# Publish to store
lzc-cli appstore publish app.lpk
```

详见 [references/dev-workflow.md](references/dev-workflow.md) 和 [references/cli-reference.md](references/cli-reference.md)

---

## Script Injection (injects)

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
