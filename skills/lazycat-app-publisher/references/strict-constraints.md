# 配置文件严格约束

本文档列出了各配置文件的**严格约束**，防止生成不存在的字段。

---

## 1. lzc-build.yml 严格约束

### 允许的字段（完整列表）

| 字段名 | 类型 | 是否必需 | 描述 |
|--------|------|----------|------|
| `manifest` | `string` | 必需 | 指定 manifest.yml 文件路径 |
| `pkgout` | `string` | 必需 | lpk 包的输出路径 |
| `icon` | `string` | 必需 | 应用图标路径，必须是 512x512 PNG 格式 |
| `contentdir` | `string` | 可选 | 额外内容目录；未配置或显式空值时不会生成内容归档 |
| `pkg_id` | `string` | 可选 | LPK v2 下覆盖最终 `package.yml.package` 的值 |
| `pkg_name` | `string` | 可选 | LPK v2 下覆盖最终 `package.yml.name` 的值 |
| `envs` | `[]string` | 可选 | 构建期变量列表，格式为 `KEY=VALUE` 字符串数组 |
| `buildscript` | `string` | 可选 | 构建脚本路径或 sh 命令 |
| `images` | `map[string]ImageBuildConfig` | 可选 | LPK v2 下用于产出 `embed:<alias>` 镜像引用 |
| `compose_override` | `ComposeOverrideConfig` | 可选 | 覆盖不支持的 Docker Compose 参数 |

### ❌ 禁止使用的字段

**以下字段在 lzc-build.yml 中不存在，禁止生成：**

- ❌ `package` - 应该在 `package.yml` 中
- ❌ `version` - 应该在 `package.yml` 中
- ❌ `name` - 应该在 `package.yml` 中
- ❌ `description` - 应该在 `package.yml` 中
- ❌ `min_os_version` - 应该在 `package.yml` 中
- ❌ `locales` - 应该在 `package.yml` 中
- ❌ `author` - 应该在 `package.yml` 中
- ❌ `license` - 应该在 `package.yml` 中
- ❌ `homepage` - 应该在 `package.yml` 中
- ❌ `application` - 应该在 `lzc-manifest.yml` 中
- ❌ `services` - 应该在 `lzc-manifest.yml` 中
- ❌ `subdomain` - 应该在 `lzc-manifest.yml` 中
- ❌ `dockerfile` - 应该在 `images` 配置内部
- ❌ `context` - 应该在 `images` 配置内部

### ✅ 正确示例

```yaml
# lzc-build.yml - 正确格式
manifest: ./lzc-manifest.yml
pkgout: ./
icon: ./icon.png
contentdir: ./content  # 可选

# 可选：内嵌镜像构建
images:
  app-runtime:
    dockerfile: ./Dockerfile
    context: .

# 可选：构建期变量
envs:
  - NODE_VERSION=18

# 可选：compose override
compose_override:
  services:
    app:
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock
```

### ❌ 错误示例

```yaml
# ❌ lzc-build.yml - 错误格式（包含不存在的字段）
package: cloud.lazycat.app.myapp  # ❌ 应在 package.yml
version: 1.0.0                    # ❌ 应在 package.yml
name: MyApp                       # ❌ 应在 package.yml
min_os_version: 1.5.0             # ❌ 应在 package.yml
subdomain: myapp                  # ❌ 应在 lzc-manifest.yml
dockerfile: ./Dockerfile          # ❌ 应在 images 配置内部
```

---

## 2. lzc-deploy-params.yml 严格约束

### 允许的字段（完整列表）

#### 顶层字段

| 字段名 | 类型 | 描述 |
|--------|------|------|
| `params` | `[]DeployParam` | 开发者定义的部署参数列表 |
| `locales` | `map` | 国际化配置 |

#### DeployParam 字段

| 字段名 | 类型 | 是否必需 | 描述 |
|--------|------|----------|------|
| `id` | `string` | 必需 | 应用内的唯一 ID，推荐使用小写英文+下划线 |
| `type` | `string` | 必需 | 字段类型，仅支持 `bool`、`lzc_uid`、`string`、`secret` |
| `name` | `string` | 必需 | 字段渲染时的名称（英文） |
| `description` | `string` | 必需 | 字段渲染时的详细介绍（英文） |
| `optional` | `bool` | 可选 | 此字段是否可选 |
| `default_value` | `string` | 可选 | 默认值，支持 `$random(len=5)` |
| `hidden` | `bool` | 可选 | 字段生效但不在界面中渲染 |

### ❌ 禁止使用的字段

**以下字段在 lzc-deploy-params.yml 中不存在，禁止生成：**

- ❌ `placeholder` - 不存在此字段
- ❌ `regex` - 不存在此字段
- ❌ `regex_message` - 不存在此字段
- ❌ `min` - 不存在此字段
- ❌ `max` - 不存在此字段
- ❌ `type: number` - 不支持 number 类型
- ❌ `type: integer` - 不支持 integer 类型
- ❌ `type: float` - 不支持 float 类型
- ❌ `type: email` - 不支持 email 类型
- ❌ `type: url` - 不支持 url 类型
- ❌ `required` - 应使用 `optional: false`
- ❌ `value` - 应使用 `default_value`

### ✅ 正确示例

```yaml
# lzc-deploy-params.yml - 正确格式
params:
  - id: admin_username
    type: string
    name: "Admin Username"
    description: "Administrator username for login"
    default_value: "admin"
    optional: false

  - id: admin_password
    type: secret
    name: "Admin Password"
    description: "Administrator password (min 8 chars recommended)"
    default_value: "$random(len=20)"
    optional: false

  - id: enable_ssl
    type: bool
    name: "Enable SSL"
    description: "Enable SSL for secure connections"
    default_value: "true"
    optional: true

  - id: owner_uid
    type: lzc_uid
    name: "Owner User"
    description: "LazyCat user who will own this application"
    optional: false

locales:
  zh:
    admin_username:
      name: "管理员用户名"
      description: "登录应用的管理员用户名"
    admin_password:
      name: "管理员密码"
      description: "管理员密码（建议至少8字符）"
    enable_ssl:
      name: "启用 SSL"
      description: "启用 SSL 安全连接"
    owner_uid:
      name: "所属用户"
      description: "拥有此应用的 LazyCat 用户"
```

### ❌ 错误示例

```yaml
# ❌ lzc-deploy-params.yml - 错误格式（包含不存在的字段）
params:
  - id: port
    type: number           # ❌ 不支持 number 类型
    name: "Port"
    description: "Service port"
    min: 1                 # ❌ 不存在 min 字段
    max: 65535             # ❌ 不存在 max 字段
    placeholder: "8080"    # ❌ 不存在 placeholder 字段

  - id: email
    type: email            # ❌ 不支持 email 类型
    regex: "^[a-z]+$"      # ❌ 不存在 regex 字段
    regex_message: "..."   # ❌ 不存在 regex_message 字段

  - id: api_key
    type: string
    required: true         # ❌ 应使用 optional: false
```

### 约束输入格式的正确做法

当需要约束输入格式时，在 `description` 中说明：

```yaml
params:
  - id: port_number
    type: string           # ✅ 使用 string 类型
    name: "Port Number"
    description: "Service port number (1-65535, default 8080)"
    default_value: "8080"
    optional: true

  - id: email_address
    type: string           # ✅ 使用 string 类型
    name: "Email Address"
    description: "Valid email address format required"
    optional: false
```

---

## 3. package.yml 严格约束

### LPK v2 格式要求

**重要：LPK v2 格式要求 `min_os_version: 1.5.0` 或更高版本！**

因为 LPK v2（tar 格式，包含 `package.yml`）是 lzcos v1.5.0+ 才支持的特性。

### 允许的字段

| 字段名 | 类型 | 是否必需 | 描述 |
|--------|------|----------|------|
| `package` | `string` | 必需 | 应用唯一包 ID |
| `version` | `string` | 必需 | 应用版本 |
| `name` | `string` | 可选 | 应用名称 |
| `description` | `string` | 可选 | 应用描述 |
| `author` | `string` | 可选 | 作者或维护者 |
| `license` | `string` | 可选 | 许可证标识或链接 |
| `homepage` | `string` | 可选 | 主页或反馈地址 |
| `min_os_version` | `string` | 可选 | 要求的最低系统版本 |
| `unsupported_platforms` | `[]string` | 可选 | 不支持的平台列表 |
| `admin_only` | `bool` | 可选 | 是否仅管理员可见 |
| `locales` | `map[string]PackageLocaleConfig` | 可选 | 多语言元数据 |
| `permissions` | `PermissionsConfig` | 可选 | 声明应用需要的权限 |

### ❌ 禁止的字段

**以下字段不应出现在 package.yml 中：**

- ❌ `application` - 应该在 `lzc-manifest.yml` 中
- ❌ `services` - 应该在 `lzc-manifest.yml` 中
- ❌ `ext_config` - 应该在 `lzc-manifest.yml` 中
- ❌ `usage` - 应该在 `lzc-manifest.yml` 中
- ❌ `subdomain` - 应该在 `lzc-manifest.yml` 中
- ❌ `routes` - 应该在 `lzc-manifest.yml` 中
- ❌ `upstreams` - 应该在 `lzc-manifest.yml` 中

### ✅ 正确示例（LPK v2）

```yaml
# package.yml - 正确格式（LPK v2）
package: cloud.lazycat.app.myapp
version: 1.0.0
name: MyApp
description: "My application description"
author: "Developer Team"
license: MIT
homepage: https://example.com
min_os_version: 1.5.0  # ✅ LPK v2 格式必须设置 1.5.0 或更高

unsupported_platforms:
  - ios

permissions:
  required:
    - net.internet
  optional:
    - document.read
    - document.write

locales:
  zh:
    name: "我的应用"
    description: "我的应用描述"
  en:
    name: "My App"
    description: "My application description"
```

### 版本要求决策表

| 格式 | 最低 min_os_version | 原因 |
|------|---------------------|------|
| LPK v2 (tar, package.yml) | **1.5.0** | LPK v2 是 v1.5.0+ 新特性 |
| LPK v1 (zip) | 无限制 | 兼容所有版本 |
| 使用 `/lzcapp/documents` | **1.5.0** | 新文档路径 |
| 使用 `permissions` | **1.5.0** | 权限声明系统 |

### ⚠️ 权限自动分析（根据 binds 路径）

**重要：当 `binds` 包含特定路径时，必须在 `permissions` 中声明对应权限！**

| binds 路径前缀 | 必需权限 id | 声明位置 | 说明 |
|---------------|------------|----------|------|
| `/lzcapp/documents` | `document.private` | `permissions.required` | 应用文稿目录，必须声明 |
| `/lzcapp/documents/${uid}` | `document.private` | `permissions.required` | 用户隔离文稿目录 |
| `/lzcapp/run/mnt/home` | `document.read` + `document.write` | `permissions.required` | 兼容旧路径（v1.7.0+ 需授权） |
| `/lzcapp/media/RemoteFS` | `media.read` | `permissions.optional` | 懒猫网盘挂载（需 enable_media_access） |
| `/lzcapp/media` | `media.read` 或 `media.write` | `permissions.optional` | 媒体目录访问 |

**检测流程**：

```
1. 解析 services.*.binds 列表
2. 匹配路径前缀（如 /lzcapp/documents）
3. 自动生成 permissions.required 或 permissions.optional
4. 提示用户确认权限声明
```

**正确示例**：

```yaml
# lzc-manifest.yml - 检测到 /lzcapp/documents 挂载
services:
  filebrowser:
    binds:
      - /lzcapp/documents:/data  # ✅ 挂载应用文稿目录

# package.yml - 自动生成的权限声明
permissions:
  required:
    - net.internet
    - document.private  # ✅ 检测到 /lzcapp/documents 时自动添加
```

**错误示例**：

```yaml
# ❌ 错误：使用 /lzcapp/documents 但 package.yml 缺少权限声明
services:
  app:
    binds:
      - /lzcapp/documents:/data

# ❌ package.yml 缺少 permissions
# 这会导致应用无法正常访问文稿目录
```

---

## 4. lzc-manifest.yml 严格约束

### LPK v2 格式要求

**LPK v2 格式下，`lzc-manifest.yml` 只包含运行结构字段！**

静态元数据（package、version、name 等）必须移到 `package.yml`。

### 允许的顶层字段

| 字段名 | 类型 | 描述 |
|--------|------|------|
| `application` | `ApplicationConfig` | lzcapp 核心服务配置 |
| `services` | `map[string]ServiceConfig` | Docker container 相关服务配置 |
| `ext_config` | `ExtConfig` | 扩展配置 |
| `usage` | `string` | 应用的使用须知 |

### ⚠️ usage 字段严格约束

**usage 只支持字符串形式，不支持多行文本块！**

| 格式 | 是否支持 | 说明 |
|------|----------|------|
| 单行字符串 | ✅ 支持 | `usage: "简单使用说明"` |
| 多行字符串（普通） | ✅ 支持 | 使用 YAML 多行字符串语法 |
| 多行文本块（缩进式） | ❌ 不支持 | 会被解析为嵌套对象 |
| 嵌套字段结构 | ❌ 不支持 | `usage.intro` 等不存在 |

**✅ 正确示例：**

```yaml
# 单行字符串
usage: "访问应用主页即可使用，无需额外配置"

# YAML 多行字符串（推荐）
usage: |
  应用使用说明：
  1. 打开应用主页
  2. 使用默认账号登录
  3. 开始使用

# 或使用 > 折叠多行
usage: >
  这是一个简单易用的应用，
  打开主页即可开始使用。
```

**❌ 错误示例（幻觉生成）：**

```yaml
# ❌ 错误：嵌套字段结构不存在
usage:
  intro: "应用介绍"         # ❌ 不存在 usage.intro
  steps:                    # ❌ 不存在 usage.steps
    - "第一步"
    - "第二步"
  tips: "使用提示"           # ❌ 不存在 usage.tips

# ❌ 错误：缩进式多行块会被解析为嵌套对象
usage:
  这是使用说明               # ❌ YAML 会将其解析为 map
  不是字符串

# ❌ 错误：幻觉生成复杂的 usage 结构
usage:
  format: markdown          # ❌ 不存在 format 字段
  content: "..."
```

**重要提醒：**
- `usage` 是一个简单字符串字段，不是复杂对象
- 不要在 `usage` 下生成任何嵌套字段
- 如需多行内容，使用 YAML 的 `|` 或 `>` 语法

### ❌ 禁止的字段（LPK v2 格式）

**LPK v2 格式下，以下静态字段不应出现在 lzc-manifest.yml 中：**

- ❌ `package` - 移到 `package.yml`
- ❌ `version` - 移到 `package.yml`
- ❌ `name` - 移到 `package.yml`
- ❌ `description` - 移到 `package.yml`
- ❌ `locales` - 移到 `package.yml`
- ❌ `author` - 移到 `package.yml`
- ❌ `license` - 移到 `package.yml`
- ❌ `homepage` - 移到 `package.yml`
- ❌ `min_os_version` - 移到 `package.yml`
- ❌ `unsupported_platforms` - 移到 `package.yml`
- ❌ `admin_only` - 移到 `package.yml`
- ❌ `permissions` - 移到 `package.yml`
- ❌ `lzc-sdk-version` - 已废弃，任何版本都不应使用

### ✅ 正确示例（LPK v2）

```yaml
# lzc-manifest.yml - 正确格式（LPK v2）
application:
  subdomain: myapp
  upstreams:
    - location: /
      backend: http://web:8080/
  public_path:
    - /

services:
  web:
    image: myapp:latest
    environment:
      - DATABASE_URL=postgresql://postgres:{{.INTERNAL.db_password}}@postgres:5432/app
    healthcheck:
      test:
        - CMD-SHELL
        - curl -f http://localhost:8080/health
      interval: 30s
      timeout: 10s
      retries: 3

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD={{.INTERNAL.db_password}}
    binds:
      - /lzcapp/var/db:/var/lib/postgresql/data
    healthcheck:
      test:
        - CMD-SHELL
        - pg_isready -U postgres
      interval: 30s

ext_config:
  enable_document_access: true
```

---

## 5. ServiceConfig 严格约束

### services 下每个服务的允许字段

| 字段名 | 类型 | 描述 |
|--------|------|------|
| `image` | `string` | Docker 镜像或 `embed:<alias>` |
| `environment` | `[]string` | 环境变量列表 |
| `entrypoint` | `*string` | 容器入口点 |
| `command` | `*string` | **必须是字符串**，不能是数组 |
| `tmpfs` | `[]string` | tmpfs 挂载 |
| `depends_on` | `[]string` | 依赖的服务 |
| `healthcheck` | `*HealthCheckConfig` | 健康检查（v1.4.1+） |
| `user` | `*string` | UID 或用户名 |
| `cpu_shares` | `int64` | CPU 份额 |
| `cpus` | `float32` | CPU 核心数 |
| `mem_limit` | `string\|int` | 内存上限 |
| `shm_size` | `string\|int` | 共享内存大小 |
| `network_mode` | `string` | 网络模式 |
| `netadmin` | `bool` | NET_ADMIN 权限 |
| `setup_script` | `*string` | 配置脚本 |
| `binds` | `[]string` | 卷挂载 |
| `runtime` | `string` | OCI runtime |

### ❌ 禁止的字段

- ❌ `health_check` - 使用 `healthcheck`（无下划线）
- ❌ `volumes` - 使用 `binds`
- ❌ `ports` - HTTP 使用 `application.upstreams`，TCP/UDP 使用 `application.ingress`
- ❌ `command` 为数组 - 必须是字符串

### ✅ 正确示例

```yaml
services:
  redis:
    image: redis:7-alpine
    command: redis-server --requirepass {{.INTERNAL.redis_password}}  # ✅ 字符串
    healthcheck:  # ✅ 无下划线
      test:
        - CMD
        - redis-cli
        - ping
      interval: 30s
    binds:
      - /lzcapp/cache/redis:/data  # ✅ 使用 binds
```

### ❌ 错误示例

```yaml
services:
  redis:
    image: redis:7-alpine
    command: ["redis-server", "--requirepass", "mypass"]  # ❌ 不能是数组
    health_check:  # ❌ 应使用 healthcheck（无下划线）
      test: ["CMD", "redis-cli", "ping"]
    volumes:  # ❌ 应使用 binds
      - /data/redis:/data
    ports:  # ❌ 应使用 application.upstreams 或 ingress
      - "6379:6379"
```

---

## 6. ApplicationConfig 严格约束

### application 下允许的字段

| 字段名 | 类型 | 描述 |
|--------|------|------|
| `image` | `string` | 应用镜像 |
| `background_task` | `bool` | 后台任务 |
| `subdomain` | `string` | 入站子域名 |
| `multi_instance` | `bool` | 多实例模式 |
| `usb_accel` | `bool` | USB 加速 |
| `gpu_accel` | `bool` | GPU 加速 |
| `kvm_accel` | `bool` | KVM 加速 |
| `depends_on` | `[]string` | 依赖的服务 |
| `file_handler` | `FileHandlerConfig` | 文件处理 |
| `routes` | `[]string` | 简化路由 |
| `upstreams` | `[]UpstreamConfig` | 高级路由 |
| `public_path` | `[]string` | 公开路径 |
| `workdir` | `string` | 工作目录 |
| `ingress` | `[]IngressConfig` | TCP/UDP 入站 |
| `environment` | `[]string` | 环境变量 |
| `health_check` | `AppHealthCheckExt` | 应用健康检查（带下划线） |
| `secondary_domains` | `[]string` | 次级域名 |
| `oidc_redirect_path` | `string` | OIDC 回调路径 |
| `injects` | `[]InjectConfig` | 脚本注入 |

### 重要区分

- **services 级别**：使用 `healthcheck`（无下划线）
- **application 级别**：使用 `health_check`（带下划线）用于 `test_url`

---

## 7. 检查清单

生成配置文件后，必须检查：

### lzc-build.yml 检查清单

- [ ] 只包含允许的字段
- [ ] 静态元数据不在此文件中
- [ ] `images` 配置结构正确
- [ ] `compose_override` 结构正确

### lzc-deploy-params.yml 检查清单

- [ ] 只包含 `params` 和 `locales`
- [ ] 每个 param 只使用 `id`, `type`, `name`, `description`, `optional`, `default_value`, `hidden`
- [ ] `type` 只使用 `bool`, `lzc_uid`, `string`, `secret`
- [ ] 没有 `placeholder`, `regex`, `regex_message`, `min`, `max`
- [ ] 没有 `type: number`
- [ ] `locales` 的 key 与 `params.id` 匹配

### package.yml 检查清单

- [ ] LPK v2 格式必须 `min_os_version: 1.5.0` 或更高
- [ ] 不包含运行结构字段（application, services 等）
- [ ] 包名格式正确（如 `cloud.lazycat.app.xxx`）
- [ ] `author` 字段已自动填入（优先级：用户指定 > GitHub URL 提取 > 应用名+Team）
  - 如果 `homepage` 是 GitHub URL，author 应为 GitHub 用户名
  - 如果无 GitHub URL，author 应为 `应用名 Team`
- [ ] **`permissions` 已根据 binds 路径自动分析生成**
  - 检测到 `/lzcapp/documents` → 添加 `document.private`
  - 检测到 `/lzcapp/run/mnt/home` → 添加 `document.read` + `document.write`
  - 检测到 `/lzcapp/media` → 添加 `media.read` 或 `media.write`
  - 网络服务 → 添加 `net.internet`

### lzc-manifest.yml 检查清单（LPK v2）

- [ ] 不包含静态元数据字段
- [ ] 只包含 `application`, `services`, `ext_config`, `usage`
- [ ] services 使用 `healthcheck`（无下划线）
- [ ] `command` 是字符串，不是数组
- [ ] 没有 `lzc-sdk-version`
- [ ] **`usage` 是字符串形式，不是嵌套结构**
- [ ] **免密登录 `when` 路径与实际登录页匹配**
- [ ] **`binds` 路径与 `package.yml.permissions` 声明匹配**
  - `/lzcapp/documents` → 需要 `document.private` 权限
  - `/lzcapp/run/mnt/home` → 需要 `document.read` + `document.write` 权限
  - `/lzcapp/media` → 需要 `media.read` 或 `media.write` 权限

### 免密登录配置检查清单

- [ ] `when` 条件中的路径与实际登录页 URL 匹配
- [ ] 已在浏览器中验证登录页路径
- [ ] 使用正确的阶段：`on: browser` 可用 hash 规则，`on: request/response` 用路径规则
- [ ] SPA 应用正确匹配 hash 路由（如 `/#/login`）
- [ ] 多入口应用已覆盖所有登录入口

---

**最后更新**: 2026-04-22
**基于**: 懒猫开发者文档 v1.5.0+
**新增**: 权限自动分析（根据 binds 路径）