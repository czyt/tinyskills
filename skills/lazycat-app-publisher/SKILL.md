---
name: lazycat-app-publisher
description: LazyCat v1.5.0+ 应用发布助手，支持智能 Docker Compose 转换、依赖分析、自动凭证生成、compose_override、高级路由（upstreams/ingress）、文件处理器、硬件加速。默认 LPK v2 格式（package.yml + lzc-manifest.yml）。触发词：Docker Compose 转 LazyCat、发布应用到 LazyCat 商店、创建 LPK 包、管理 LazyCat 应用生命周期。
preferences:
  - id: add_root_to_public_path
    name: 添加 / 到 public_path
    description: 自动在生成的 manifest 中添加 "/" 到 application.public_path
    type: boolean
    default: true
  - id: manifest_multilingual
    name: Manifest 多语言支持
    description: 在 manifest 文件中生成中英文双语 locales
    type: boolean
    default: true
  - id: simple_app_optimization
    name: 简单应用优化
    description: 简单应用跳过 lzc-deploy-params.yml 生成
    type: boolean
    default: true
  - id: auto_healthcheck
    name: 自动健康检查
    description: 自动为服务添加健康检查配置
    type: boolean
    default: true
  - id: auto_resource_limits
    name: 自动资源限制
    description: 自动为服务添加合理的资源限制
    type: boolean
    default: true
  - id: minimal_docs
    name: 最简文档
    description: 只生成 README.md，跳过其他 markdown 文件
    type: boolean
    default: true
  - id: background_task
    name: 后台任务模式
    description: 默认将 application.background_task 设为 true，适用于长时间运行的后台服务
    type: boolean
    default: false
  - id: package_prefix
    name: 包名前缀
    description: 应用包名默认前缀（community.lazycat.app、cloud.lazycat.app 或自定义）
    type: string
    default: cloud.lazycat.app
  - id: generate_compose_override
    name: 生成 compose_override
    description: 在 lzc-build.yml 中为不支持的字段生成 compose_override 部分
    type: boolean
    default: true
  - id: passwordless_login
    name: 免密登录配置
    description: 为有密码体系的应用自动配置免密登录（使用 injects）
    type: boolean
    default: true
---

# LazyCat 应用发布助手

协助将 Docker Compose 文件和 Docker 命令转换为 LazyCat Cloud 应用配置，提供**智能依赖分析**和**自动配置优化**。

## Reference Documents

| Document | Content |
|----------|---------|
| [references/strict-constraints.md](references/strict-constraints.md) | **严格约束 - 各配置文件允许/禁止字段** ⭐ |
| [references/passwordless-login.md](references/passwordless-login.md) | **免密登录配置 - 所有应用必备** ⭐ |
| [references/go-template-conditional.md](references/go-template-conditional.md) | **Go Template 条件渲染 - {{if}}/{{else}}/{{end}}** ⭐ 新增 |
| [references/version-features.md](references/version-features.md) | OS版本与特性对照表 - min_os_version 设置 |
| [references/advanced-features.md](references/advanced-features.md) | 高级功能 - 多入口、compose_override、资源限制、网络等 ⭐ |
| [references/quick-reference.md](references/quick-reference.md) | 快速参考 - 常用转换规则和命令 |
| [references/healthcheck.md](references/healthcheck.md) | 健康检查配置 - v1.4.1+ 格式 |
| [references/manifest.md](references/manifest.md) | Manifest 完整格式规范 |
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
| **多入口 `application.entries`** | **v1.4.3** | 多入口支持 - 主界面+管理后台等 ⭐ |
| `/lzcapp/documents` (新路径) | v1.5.0 | 替代旧路径 `/lzcapp/document` |
| `permissions` 声明 | v1.5.0 | 权限系统 |
| `services.[].healthcheck` | v1.4.1 | 100% Docker 兼容，详见下方映射表 |
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
| 使用 **多入口 `entries`** | **1.4.3** ⭐ |
| 使用 `upstreams`, `mem_limit` | 1.3.8 |

详见 [references/version-features.md](references/version-features.md) 和 [references/strict-constraints.md](references/strict-constraints.md)

---

## Conversion Workflow

### Phase 1: 输入分析

**输入**: Docker Compose 文件 或 Docker Run 命令
**输出**: 服务分类结果（Internal/External），参数需求清单

#### Step 1.1: 解析源文件

```
用户提供 docker-compose.yml 或 docker run 命令
→ 解析 services、ports、volumes、environment、depends_on 等
```

#### Step 1.2: 服务分类

使用智能分析逻辑判断服务类型：

| 判断条件 | 类型 | 处理方式 |
|---------|------|---------|
| 有 healthcheck + 无外部端口 | **Internal** | 自动配置密码 |
| 有外部端口 | **External** | 用户配置 upstreams |
| 有密码体系 | **密码应用** | ⚠️ 检查点：确认是否配置免密登录 |

#### Step 1.3: 检查应用商店

**⚠️ 检查点**: 自动搜索应用商店，确认同名应用是否已存在

```bash
GET https://search.lazycat.cloud/api/v1/app?keyword={app_name}&size=48
```

如果找到匹配：
- 提示用户：「应用商店已存在同名应用 XXX，是否继续创建？」
- 用户确认后继续，否则终止

详见 [references/intelligent-analysis.md](references/intelligent-analysis.md)

### Phase 2: 配置生成

**输入**: 服务分类结果
**输出**: package.yml + lzc-manifest.yml + lzc-build.yml（LPK v2 格式）

#### Step 2.1: 生成 package.yml（静态元数据）

**⚠️ 检查点**: 确认包名前缀（默认 `cloud.lazycat.app`）

**⚠️ 检查点**: 确认 author 来源（按以下优先级）：

| 优先级 | 来源 | 规则 |
|--------|------|------|
| 1 | 用户明确指定 | 使用用户输入的作者名 |
| 2 | GitHub URL | 从 homepage 提取 GitHub 用户名/组织名 |
| 3 | 默认生成 | 使用 `应用名 + Team` |

**Author 自动填入示例：**

| homepage | 提取结果 |
|----------|---------|
| `https://github.com/dani-garcia/vaultwarden` | `dani-garcia` |
| `https://github.com/blinkospace/blinko` | `blinkospace` |
| `https://nextcloud.com` (非 GitHub) | `Nextcloud Team` |

详见 [references/intelligent-analysis.md](references/intelligent-analysis.md) 的 Author Auto-Fill Logic 章节

```yaml
package: cloud.lazycat.app.myapp  # 用户可修改前缀
version: 1.0.0
name: MyApp
description: "应用描述"
min_os_version: 1.5.0  # ✅ LPK v2 强制要求
homepage: https://github.com/user/repo
author: user  # ✅ 从 GitHub URL 自动提取，或使用 "MyApp Team"
```

#### Step 2.2: 生成 lzc-manifest.yml（运行结构）

**⚠️ 检查点**: 确认路由方式（upstreams 或 ingress）

```yaml
application:
  subdomain: myapp
  upstreams:  # HTTP 服务推荐
    - location: /
      backend: http://web:8080/
  # 或 ingress（TCP/UDP 服务）
  # ingress:
  #   - port: 5432
  #     proto: tcp

services:
  db:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD={{.INTERNAL.db_password}}  # Internal 服务自动配置
```

#### Step 2.3: 生成 lzc-build.yml（构建配置）

```yaml
manifest: ./lzc-manifest.yml
pkgout: ./
icon: ./icon.png
# compose_override 用于不支持的字段（可选）
```

#### Step 2.4: 配置免密登录（密码应用必须）

**⚠️ 检查点**: 如果应用有密码体系，必须询问用户免密登录方案

| 方案 | 适用场景 | 配置复杂度 |
|------|---------|-----------|
| simple-inject-password | 固定账号/部署参数提供 | 简单 |
| 三阶段联动 | 用户首次创建账号 | 中等 |
| Basic Auth Header | 上游服务验证 | 简单 |

详见 [references/passwordless-login.md](references/passwordless-login.md)

### Phase 3: 打包发布

**输入**: 配置文件已生成
**输出**: LPK 包 + 发布到应用商店

#### Step 3.1: 本地验证

```bash
# 构建 LPK 包（默认 LPK v2）
lzc-cli project release -o app.lpk

# 查看包信息
lzc-cli lpk info app.lpk
```

**⚠️ 检查点**: 确认包内容正确后再发布

#### Step 3.2: 发布到应用商店

```bash
lzc-cli appstore publish app.lpk
```

---

## Quick Start

### Convert Docker Compose

**输入格式**: Docker Compose YAML 文件路径或内容
**输出格式**: LPK v2 包目录（package.yml + lzc-manifest.yml + lzc-build.yml）

```
Convert this docker-compose.yml to LazyCat app format:
[provide docker-compose.yml content or file path]

示例输入：
services:
  web:
    image: nginx:latest
    ports:
      - "80:80"
  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: mypassword

预期输出：
├── package.yml       # 包元数据
├── lzc-manifest.yml  # 运行配置
├── lzc-build.yml     # 构建配置
└── icon.png          # 应用图标（需用户提供）
```

### Convert Docker Run

**输入格式**: Docker Run 命令字符串
**输出格式**: 同上（LPK v2）

```
Convert this docker run command to LazyCat app:
docker run -d -p 8080:80 -e APP_ENV=production --name myapp nginx:latest

解析规则：
- -p → application.upstreams 或 ingress
- -e → services.*.environment
- -v → services.*.binds
- --name → application.subdomain
```

### Publish to Store

**输入格式**: LPK 包文件路径
**输出**: 发布到应用商店，返回应用 ID

```
Help me publish this application to LazyCat Cloud:
[provide LPK package path or directory]

步骤：
1. 验证 LPK 包结构
2. 确认应用商店无同名应用
3. 执行 lzc-cli appstore publish
4. 返回发布结果
```

---

## 智能分析逻辑

### 服务分类

```python
def classify_service(service_config):
    has_healthcheck = 'healthcheck' in service_config
    has_external_ports = 'ports' in service_config

    # Internal 服务 = 有 healthcheck + 无外部端口
    if has_healthcheck and not has_external_ports:
        return 'INTERNAL'  # 自动配置
    else:
        return 'EXTERNAL'  # 用户配置
```

| 服务 | 健康检查 | 外部端口 | 类型 | 配置方式 |
|------|---------|---------|------|---------|
| PostgreSQL | ✅ | ❌ | Internal | 自动生成密码 |
| Redis | ✅ | ❌ | Internal | 自动生成密码 |
| Web App | ❌ | ✅ | External | 用户配置 |

### 参数模板

| 场景 | 推荐函数 | 示例 |
|------|---------|------|
| 内部服务密码 | `{{.INTERNAL.xxx}}` | `{{.INTERNAL.db_password}}` |
| 用户必须配置 | `{{.U.xxx}}` | `{{.U.jwt_secret_key}}` |
| 系统域名 | `{{.S.AppDomain}}` | `{{.S.AppDomain}}` (不含协议) |
| 稳定密钥 | `{{ stable_secret "seed"}}` | `{{ stable_secret "api_key"}}` |
| 运行时变量 | `${LAZYCAT_*}` | `${LAZYCAT_APP_ID}` |
| 条件渲染 | `{{if}}/{{else}}/{{end}}` | 根据参数动态配置 |

详见 [references/intelligent-analysis.md](references/intelligent-analysis.md) 和 **[references/go-template-conditional.md](references/go-template-conditional.md)** ⭐

### Setup Wizard 约束

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
| `healthcheck` | `services.*.healthcheck` (v1.4.1+, 100%兼容) ⭐ |

### Healthcheck 快速参考

**v1.4.1+ 关键变更**：
- ✅ `healthcheck`（无下划线）- 100% Docker Compose 兼容
- ❌ `health_check`（带下划线）- 已废弃，迁移时需改字段名并添加时间单位

```yaml
# Docker Compose → LazyCat 完全兼容
services:
  postgres:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s  # 必须带单位（旧格式可能无单位）
```

**⚠️ Rule 1**: 不要自动添加 healthcheck（容器可能缺少 curl/wget）

详见 [references/healthcheck.md](references/healthcheck.md)

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

## 最佳实践

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

### ❌ Avoid - 常见错误

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

## 开发工作流

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

### 快速决策表

| 目标 | 使用命令 |
|------|---------|
| UI 热更新 | `project deploy` + `npm run dev` |
| 后端代码修改 | `project deploy` + `project sync --watch` + `project exec` |
| 构建发布包 | `project release` |

### 主要命令

```bash
# 从模板创建项目
lzc-cli project create myapp -t hello-vue

# 部署（有 lzc-build.dev.yml 则用，否则用 lzc-build.yml）
lzc-cli project deploy

# 使用 release 配置部署
lzc-cli project deploy --release

# 同步代码（监听模式）
lzc-cli project sync --watch

# 进入容器
lzc-cli project exec /bin/sh

# 查看日志
lzc-cli project log -f

# 构建发布包（默认 LPK v2，需 lzc-cli v2.0.0+）
lzc-cli project release -o app.lpk

# 查看 LPK 信息
lzc-cli lpk info app.lpk

# 发布到应用商店
lzc-cli appstore publish app.lpk
```

详见 [references/dev-workflow.md](references/dev-workflow.md) 和 [references/cli-reference.md](references/cli-reference.md)

---

## LPK v1 到 v2 迁移

### 使用转换脚本

提供 Python 脚本将现有 LPK v1 包转换为 v2 格式：

```bash
# 基本用法
python scripts/lpk_v1_to_v2.py app.lpk

# 指定输出
python scripts/lpk_v1_to_v2.py app.lpk new-app.lpk

# 输出到目录
python scripts/lpk_v1_to_v2.py app.lpk ./output/
```

**转换器做什么：**
1. 解压 LPK v1（zip 格式）
2. 将 `manifest.yml` 拆分为：
   - `package.yml` - 静态元数据（package, version, name, description 等）
   - `manifest.yml` - 运行结构（application, services, ext_config）
3. 重新打包为 LPK v2（tar 格式）

**依赖要求：**
```bash
pip install pyyaml
```

### 手动迁移

简单场景可以手动迁移：

```bash
# 1. 解压 v1
unzip app.lpk -d temp/

# 2. 从 manifest.yml 静态字段创建 package.yml
cat > package.yml << 'EOF'
package: your.app.id
version: 1.0.0
name: Your App
description: App description
min_os_version: 1.3.8
EOF

# 3. 从 manifest.yml 移除静态字段（只保留 application, services, ext_config, usage）

# 4. 重新打包为 v2
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

执行转换时，**遇到以下情况必须暂停并询问用户**：

#### ❌ Rule 1: DO NOT Auto-Add Healthcheck
如果原始 docker-compose.yml 没有 healthcheck，不要自动添加。容器可能缺少 curl/wget 工具。

**⚠️ 检查点**: 发现服务无 healthcheck 时，询问用户：
- 「服务 X 无健康检查配置，是否需要添加？」
- 若用户选择添加，提供常见的 healthcheck 模板（见 [healthcheck.md](references/healthcheck.md)）

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

**⚠️ 检查点**: 发现文件挂载（如 `/path/file.conf:/etc/file.conf`）时，提示用户转换为 contentdir 方案。

#### ❌ Rule 3: LPK v2 MUST Set min_os_version: 1.5.0
LPK v2 格式（tar + package.yml）是 v1.5.0+ 才支持的特性：
```yaml
# package.yml
package: cloud.lazycat.app.myapp
version: 1.0.0
min_os_version: 1.5.0  # ✅ 必须设置
```

**⚠️ 检查点**: 若用户需要兼容旧版本（< v1.5.0），提示切换到 LPK v1 格式（zip）。

#### ❌ Rule 4: DO NOT Generate Invalid Fields
严格按官方规范生成配置文件，禁止生成不存在的字段：
- lzc-build.yml: 禁止 `package`, `version`, `name`, `subdomain` 等
- lzc-deploy-params.yml: 禁止 `placeholder`, `regex`, `min`, `max`, `type: number`

**⚠️ 检查点**: 每次生成配置后，对照 [strict-constraints.md](references/strict-constraints.md) 验证字段有效性。

#### ❌ Rule 5: All Password Apps MUST Have Passwordless Config
如果应用自带密码体系，必须配置免密登录：
- 使用 `simple-inject-password` 自动填充
- 或使用三阶段联动记录用户修改的密码

**⚠️ 检查点**: 检测到密码字段（如 `PASSWORD`, `SECRET_KEY`, `ADMIN_PASSWORD`）时，**强制询问**：
- 「检测到密码体系，请选择免密登录方案：[简单自动填充 / 三阶段联动 / Basic Auth]」
- 用户确认后才能继续生成配置

---

## ⚠️ 边界条件与异常处理

### 构建阶段异常

| 异常类型 | 检测方法 | 处理方案 |
|---------|---------|---------|
| **镜像拉取失败** | `lzc-cli project release` 报错 | 1. 检查镜像源是否可访问<br>2. 提示用户配置代理或使用 `registry.lazycat.cloud`<br>3. 使用 `embed:<alias>` 内嵌镜像构建 |
| **manifest 验证失败** | 字段格式错误 | 1. 对照 strict-constraints.md 检查<br>2. 显示具体错误字段和修复建议<br>3. 提供正确格式示例 |
| **图标文件缺失** | icon.png 不存在 | 1. 提示用户准备 512x512 PNG 图标<br>2. 可使用占位图标（但会警告） |
| **权限不足** | 文件写入失败 | 1. 检查目标目录权限<br>2. 提示用户使用 sudo 或调整目录权限 |

### 网络阶段异常

| 异常类型 | 检测方法 | 处理方案 |
|---------|---------|---------|
| **应用商店 API 不可达** | GET 请求失败 | 1. 提示用户网络可能不可用<br>2. 可跳过检查继续创建（但用户需手动确认无重名）<br>3. 使用离线模式 |
| **镜像源不可达** | docker pull 失败 | 1. 推荐使用 `registry.lazycat.cloud` 镜像源<br>2. 配置 compose_override 使用其他源<br>3. 使用内嵌镜像 |

### 运行时异常

| 异常类型 | 检测方法 | 处理方案 |
|---------|---------|---------|
| **应用启动失败** | 健康检查超时 | 1. 检查 `start_period` 设置<br>2. 使用 `handlers.error_page_templates` 自定义错误页<br>3. 查看容器日志排查 |
| **502/404 错误** | HTTP 错误 | 配置错误页面模板：<br>`application.handlers.error_page_templates: {502: /lzcapp/pkg/content/errors/502.html.tpl}` |
| **服务依赖超时** | depends_on 等待失败 | 1. 检查依赖服务是否正常启动<br>2. 调整 `start_period` 时间<br>3. 检查 `healthcheck` 配置 |

### 兼容性警告

| 场景 | 问题描述 | 处理方案 |
|------|---------|---------|
| **系统降级 (v1.3.8+)** | v1.3.8+ 降级后应用数据不可用 | **⚠️ 强制警告**：告知用户升级后不可降级 |
| **user 字段格式 (v1.4.2)** | `services.xx.user: 1000` 会报错 | 必须使用引号：`user: "1000"` |
| **environment 空值 (v1.4.2)** | `environment:` 空数组会报错 | 不要留空，删除字段或填写值 |
| **compose_override 使用** | 需联系官方备案 | **⚠️ 检查点**：使用前提示用户联系开发者群或客服 |
| **文档路径 (v1.5.0)** | `/lzcapp/document` 废弃 | 使用新路径 `/lzcapp/documents` |

### 恢复流程

当构建或运行失败时，按以下步骤恢复：

```bash
# 1. 查看详细错误日志
lzc-cli project log -f

# 2. 进入容器排查
lzc-cli project exec /bin/sh

# 3. 检查 manifest 渲染结果
cat /lzcapp/run/manifest.yml

# 4. 回滚到上一版本（如果有）
# 手动删除失败的部署，重新执行 lzc-cli project release
```

### 错误页面模板配置

当应用出错时，可自定义错误页面：

```yaml
# lzc-manifest.yml
application:
  handlers:
    error_page_templates:
      502: /lzcapp/pkg/content/errors/502.html.tpl
      404: /lzcapp/pkg/content/errors/404.html.tpl
```

模板可使用 `{{ .ErrorDetail }}` 显示具体错误：

```html
<html>
  <body>
    <h1>应用发生错误</h1>
    <p>失败原因: {{ .ErrorDetail}}</p>
    <p>请稍后再试</p>
  </body>
</html>
```

---

## 应用商店检查（自动）

每当用户请求转换或创建应用时，技能会**自动**检查懒猫应用商店中是否已存在同名应用：

```bash
# 搜索 API
GET https://search.lazycat.cloud/api/v1/app?keyword={app_name}&size=48
```

如果找到匹配应用，会提示用户是否继续创建。

---

## 偏好设置

| 偏好 | 默认值 | 说明 |
|------|--------|------|
| 添加 / 到 public_path | true | 自动添加 "/" 到 public_path |
| Manifest 多语言 | true | 生成中英文 locales |
| 简单应用优化 | true | 简单应用跳过 params 生成 |
| 自动健康检查 | true | 自动添加 healthcheck |
| 自动资源限制 | true | 自动添加资源限制 |
| 最简文档 | true | 只生成 README.md |
| 后台任务模式 | false | 设置 background_task: true |
| 包名前缀 | cloud.lazycat.app | 包名前缀 |
| 生成 compose_override | true | 生成 compose_override |
| 免密登录 | true | **为密码体系应用自动配置免密登录** |

---

## 示例

### 示例 1：简单 Web 应用

**输入（docker-compose.yml）：**
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

**输出（智能转换）：**
```yaml
services:
  postgres:
    environment:
      - POSTGRES_PASSWORD={{.INTERNAL.db_password}}  # 自动
    healthcheck: {...}

  app:
    environment:
      - DATABASE_URL=postgresql://postgres:{{.INTERNAL.db_password}}@postgres:5432/app
      - SECRET_KEY={{.U.secret_key}}  # 用户配置
```

更多示例见 [references/docker-compose-examples.md](references/docker-compose-examples.md) 和 [references/real-world-examples.md](references/real-world-examples.md)

---

## 参考资料

- **官方文档**: https://developer.lazycat.cloud
- **文档仓库**: https://gitee.com/lazycatcloud/lzc-developer-doc
- **应用商店**: https://gitee.com/lazycatcloud/appdb
