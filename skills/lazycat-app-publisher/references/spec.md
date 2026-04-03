# 懒猫微服官方规范参考

本文档整合了懒猫微服官方文档的关键内容，使技能可以在任何设备上使用，无需依赖本地路径。

**文档来源：** 懒猫开发者文档 (https://developer.lazycat.cloud)

---

## 📋 目录

1. [Manifest 规范 (lzc-manifest.yml)](#manifest-规范)
2. [Package 规范 (package.yml)](#package-规范)
3. [部署参数规范 (lzc-deploy-params.yml)](#部署参数规范)
4. [构建配置规范 (lzc-build.yml)](#构建配置规范)
5. [高级功能参考](#高级功能参考)

---

# Manifest 规范

## 一、概述

`lzc-manifest.yml` 是用于定义应用运行结构与部署相关配置的文件。本文档详细描述其结构和各字段的含义。

说明：

1. **`LPK v2`** / `package.yml` 新流程以 `lzcos v1.5.0+` 为前提，构建需配合 `lzc-cli v2.0.0+`。
2. 自 `LPK v2` 起，静态包元数据统一放入 `package.yml`，包括 `package`、`version`、`name`、`description`、`locales`、`author`、`license`、`homepage`、`min_os_version`、`unsupported_platforms`、`admin_only` 与 `permissions`。
3. `lzc-manifest.yml` 只保留运行结构字段：`application`、`services`、`ext_config`、`usage`。
4. `LPK v1` 仍兼容旧布局，允许这些静态字段继续保留在 `lzc-manifest.yml` 顶层。
5. 对于需要访问用户文稿的应用，必须在 `ext_config` 中声明 `enable_document_access: true`（v1.5.0+）。

## 二、顶层数据结构 `ManifestConfig`

### 2.1 基本信息

| 字段名 | 类型 | 描述 |
| ---- | ---- | ---- |
| `usage` | `string` | 应用的使用须知，如果不为空，则微服内每个用户第一次访问本应用时会自动渲染 |

### 2.2 其他配置

| 字段名 | 类型 | 描述 |
| ---- | ---- | ---- |
| `ext_config` | `ExtConfig` | 扩展配置 |
| `application` | `ApplicationConfig` | lzcapp 核心服务配置 |
| `services` | `map[string]ServiceConfig` | Docker container 相关服务配置 |

---

## 三、`IngressConfig` 配置 (TCP/UDP)

### 3.1 网络配置

| 字段名 | 类型 | 描述 |
| ---- | ---- | ---- |
| `protocol` | `string` | 协议类型，支持 `tcp` 或 `udp` |
| `port` | `int` | 目标端口号，若为空，则使用实际入站的端口 |
| `service` | `string` | 服务容器的名称，若为空，则为 `app` |
| `description` | `string` | 服务描述 |
| `publish_port` | `string` | 允许的入站端口号，可以为具体的端口号或 `1000~50000` 这种端口范围 |
| `send_port_info` | `bool` | 以 little ending 发送 uint16 类型的实际入站端口给目标端口后再进行数据转发 |
| `yes_i_want_80_443` | `bool` | 为 true 则允许将 80,443 流量转发到应用，此时流量完全绕过系统，鉴权、唤醒等都不会生效 |

**示例：**

```yaml
application:
  ingress:
    - protocol: tcp
      port: 22
      service: gitlab
      description: "SSH for Git operations"
    - protocol: tcp
      port: 5432
      service: postgres
      publish_port: "20000-30000"
```

---

## 四、`ApplicationConfig` 配置

### 4.1 基础配置

| 字段名 | 类型 | 描述 |
| ---- | ---- | ---- |
| `image` | `string` | 应用镜像，若无特殊要求，请留空使用系统默认镜像 (alpine3.21) |
| `background_task` | `bool` | 若为 `true` 则会自动启动并且不会被自动休眠 |
| `subdomain` | `string` | 本应用的入站子域名，应用打开默认使用此子域名 |
| `multi_instance` | `bool` | 是否以多实例形式部署（每个用户独立容器） |
| `usb_accel` | `bool` | 挂载相关设备到所有服务容器内的 `/dev/bus/usb` |
| `gpu_accel` | `bool` | 挂载相关设备到所有服务容器内的 `/dev/dri` |
| `kvm_accel` | `bool` | 挂载相关设备到所有服务容器内的 `/dev/kvm` 和 `/dev/vhost-net` |
| `depends_on` | `[]string` | 依赖的其他容器服务，仅支持本应用内的其他服务 |

### 4.2 功能配置

| 字段名 | 类型 | 描述 |
| ---- | ---- | ---- |
| `file_handler` | `FileHandlerConfig` | 声明本应用支持的扩展名 |
| `routes` | `[]string` | 简化版 HTTP 路由规则 |
| `upstreams` | `[]UpstreamConfig` | 高级版本 HTTP 路由规则，与 routes 共存 |
| `public_path` | `[]string` | 独立鉴权的 HTTP 路径列表；若 `package.yml.admin_only: true`，则不能同时声明非空值 |
| `workdir` | `string` | `app` 容器启动时的工作目录 |
| `ingress` | `[]IngressConfig` | TCP/UDP 服务相关 |
| `environment` | `[]string` | `app` 容器的环境变量 |
| `health_check` | `AppHealthCheckExt` | `app` 容器的健康检测 |
| `secondary_domains` | `[]string` | 次级域名列表 (v1.3.9+) |
| `oidc_redirect_path` | `string` | OIDC 回调路径 (用于 OIDC 集成) |

---

## 五、`HealthCheckConfig` 配置

### 5.1 AppHealthCheckExt (application 级别)

| 字段名 | 类型 | 描述 |
| ---- | ---- | ---- |
| `test_url` | `string` | 扩展的检测方式，直接提供一个 HTTP URL |
| `disable` | `bool` | 禁用本容器的健康检测 |
| `start_period` | `string` | 启动等待阶段时间 |
| `timeout` | `string` | 单次检测耗时超过 timeout 则认为检测失败 (v1.4.1+) |

### 5.2 HealthCheckConfig (service 级别)

| 字段名 | 类型 | 描述 |
| ---- | ---- | ---- |
| `test` | `[]string` | 在对应容器内执行什么命令进行检测 |
| `timeout` | `string` | 单次检测耗时超过 timeout 则认为本次检测失败 |
| `interval` | `string` | 每次检测间隔时间 |
| `retries` | `int` | 连续多少次检测失败后让整个容器进入 unhealthy 状态，默认值 1 |
| `start_period` | `string` | 启动等待阶段时间 |
| `start_interval` | `string` | 在 start_period 时间内，每隔多久执行一次检测 |
| `disable` | `bool` | 禁用本容器的健康检测 |

**⚠️ v1.4.1+ 重要变更：**
- Services 使用 `healthcheck` (无下划线) - 100% Docker Compose 兼容
- Application 使用 `health_check` (带下划线) for `test_url`

---

## 六、`ExtConfig` 配置

| 字段名 | 类型 | 描述 |
| ---- | ---- | ---- |
| `enable_document_access` | `bool` | 如果为 true 则挂载用户文稿目录到 `/lzcapp/documents`（v1.5.0+） |
| `enable_media_access` | `bool` | 如果为 true 则将 media 目录挂载到 `/lzcapp/media` |
| `disable_grpc_web_on_root` | `bool` | 如果为 true 则不再劫持应用的 grpc-web 流量 |
| `default_prefix_domain` | `string` | 会调整启动器中点击应用后打开的最终域名，可以写任何不含 `.` 的字符串 |

**说明：**

1. `enable_document_access` 在 v1.5.0+ 中需要配合 `permissions` 中的 `document.read` 或 `document.write` 使用
2. 旧路径 `/lzcapp/document` 已废弃，新代码请使用 `/lzcapp/documents`（复数形式）

**示例：**

```yaml
ext_config:
  enable_document_access: true

services:
  app:
    binds:
      - /lzcapp/documents:/app/data/documents
```

---

## 七、`ServiceConfig` 配置

### 7.1 容器配置

| 字段名 | 类型 | 描述 |
| ---- | ---- | ---- |
| `image` | `string` | 对应容器的 Docker 镜像，支持合法镜像引用，也支持 `embed:<alias>`（alias 由 `lzc-build.yml.images` 定义） |
| `environment` | `[]string` | 对应容器的环境变量 |
| `entrypoint` | `*string` | 对应容器的 entrypoint (可选) |
| `command` | `*string` | 对应容器的 command (可选，**必须是字符串类型**) |
| `tmpfs` | `[]string` | 挂载 tmpfs volume (可选) |
| `depends_on` | `[]string` | 依赖的其他容器服务 (app 这个名字除外) |
| `healthcheck` | `*HealthCheckConfig` | 容器的健康检测策略 (v1.4.1+) |
| `user` | `*string` | 容器运行的 UID 或 username (可选) |
| `cpu_shares` | `int64` | CPU 份额 |
| `cpus` | `float32` | CPU 核心数 |
| `mem_limit` | `string\|int` | 容器的内存上限 |
| `shm_size` | `string\|int` | /dev/shm/ 大小 |
| `network_mode` | `string` | 网络模式，目前只支持 `host` 或留空 |
| `netadmin` | `bool` | 若为 `true`，则容器具备 `NET_ADMIN` 权限 |
| `setup_script` | `*string` | 配置脚本，脚本内容会以 root 权限执行 |
| `binds` | `[]string` | 仅 `/lzcapp/var`, `/lzcapp/cache` 路径下的数据会永久保留 |
| `runtime` | `string` | 指定 OCI runtime，支持 `runc` 和 `sysbox-runc` |

**⚠️ command 字段注意事项：**
- **必须是字符串类型**，不能是数组
- 示例：`command: redis-server --requirepass mypass`
- 错误：`command: ["redis-server", "--requirepass", "mypass"]`

---

## 八、`FileHandlerConfig` 配置

| 字段名 | 类型 | 描述 |
| ---- | ---- | ---- |
| `mime` | `[]string` | 支持的 MIME 类型列表 |
| `actions` | `map[string]string` | 动作映射 |

**示例：**

```yaml
application:
  file_handler:
    mime:
      - application/pdf
      - text/*  # 通配符支持
      - x-lzc-extension/md  # 基于扩展名
    actions:
      open: /open?file=%u
      download: /download?file=%u
```

---

## 九、`UpstreamConfig` 配置 (HTTP 路由)

| 字段名 | 类型 | 描述 |
| ---- | ---- | ---- |
| `location` | `string` | 入口匹配的路径 |
| `disable_trim_location` | `bool` | 转发到 backend 时，不要自动去掉 location 前缀 (v1.3.9+) |
| `domain_prefix` | `string` | 入口匹配的域名前缀 |
| `backend` | `string` | 上游的地址，需要是一个合法的 URL，支持 http, https, file 三个协议 |
| `use_backend_host` | `bool` | 如果为 true，则访问上游时 HTTP host header 使用 backend 中的 host |
| `backend_launch_command` | `string` | 自动启动此字段里的程序 |
| `trim_url_suffix` | `string` | 自动删除请求后端时 URL 可能携带的指定字符 |
| `disable_backend_ssl_verify` | `bool` | 请求 backend 时不进行 SSL 安全验证 |
| `disable_auto_health_chekcing` | `bool` | 禁止系统自动针对此条目生成的健康检测 |
| `disable_url_raw_path` | `bool` | 如果为 true 则删除 HTTP header 中的 raw URL |
| `remove_this_request_headers` | `[]string` | 删除这个列表内的 HTTP request header，比如 "Origin"、"Referer" |
| `fix_websocket_header` | `bool` | 自动将 Sec-Websocket-xxx 替换为 Sec-WebSocket-xxx |
| `dump_http_headers_when_5xx` | `bool` | 如果 HTTP 上游出现 5xx，则 dump 请求 |
| `dump_http_headers_when_paths` | `[]string` | 如果遇到此路径下的 HTTP，则 dump 请求 |

**示例：**

```yaml
application:
  subdomain: myapp
  upstreams:
    - location: /
      backend: http://myapp:8080/
    - location: /api
      backend: http://backend:3000/
      use_backend_host: true
      remove_this_request_headers:
        - Origin
        - Referer
```

---

## 十、本地化 `I10nConfigItem` 配置

配置 `locales` 使应用支持多语言，支持设置的 language key 规范可参考 BCP 47 标准。

| 字段名 | 类型 | 描述 |
| ---- | ---- | ---- |
| `name` | `string` | 应用名称本地化字段 |
| `description` | `string` | 应用描述本地化字段 |
| `usage` | `string` | 应用的使用须知本地化字段 |

**示例：**

```yaml
locales:
  zh:
    name: "我的应用"
    description: "我的应用描述"
  zh_CN:
    name: "我的应用"
    description: "我的应用描述"
  en:
    name: "My App"
    description: "My application description"
  ja:
    name: "マイアプリ"
    description: "アプリケーションの説明"
```

---

# Package 规范

## package.yml 规范

`package.yml` 用于定义 LPK 的静态包元数据，以及开发者声明的权限需求范围。

**前提：**

- `lzcos v1.5.0+`
- `LPK v2`
- `lzc-cli v2.0.0+`

### 字段说明

| 字段名 | 类型 | 描述 |
|--------|------|------|
| `package` | `string` | 必填；应用唯一包 ID |
| `version` | `string` | 必填；应用版本 |
| `name` | `string` | 可选；应用名称 |
| `description` | `string` | 可选；应用描述 |
| `author` | `string` | 可选；作者或维护者 |
| `license` | `string` | 可选；许可证标识或链接 |
| `homepage` | `string` | 可选；主页或反馈地址 |
| `admin_only` | `bool` | 可选；是否仅管理员可见。若为 `true`，则不允许同时声明非空 `application.public_path` |
| `min_os_version` | `string` | 可选；要求的最低系统版本 |
| `unsupported_platforms` | `[]string` | 可选；不支持的平台列表 |
| `locales` | `map[string]PackageLocaleConfig` | 可选；多语言元数据 |
| `permissions` | `PermissionsConfig` | 可选；声明应用需要的权限（v1.5.0+） |

### Permissions 配置

| 字段名 | 类型 | 描述 |
|--------|------|------|
| `required` | `[]string` | 应用正常运行必需的权限 id 列表 |
| `optional` | `[]string` | 应用可选使用的权限 id 列表 |

**可用权限 id：**

| 权限 id | 名称 | 描述 |
|---------|------|------|
| `net.internet` | 访问互联网 | 允许应用访问公网网络资源 |
| `net.lan` | 访问局域网 | 允许应用访问当前局域网内的设备与服务 |
| `net.host` | 使用宿主网络 | 允许应用使用宿主网络 |
| `document.private` | 私有文稿 | 允许应用使用 `/lzcapp/documents/$uid` 私有文稿目录 |
| `document.read` | 读取文稿 | 允许应用读取用户文稿目录中的内容 |
| `document.write` | 写入文稿 | 允许应用修改或写入用户文稿目录中的内容 |
| `media.read` | 读取媒体 | 允许应用读取系统媒体目录中的内容 |
| `media.write` | 写入媒体 | 允许应用修改或写入系统媒体目录中的内容 |
| `device.dri.render` | 访问 DRI Render | 允许应用访问 DRI render 设备 |
| `device.usb` | 访问 USB 设备 | 允许应用访问连接到微服的 USB 设备 |
| `device.kvm` | 访问 KVM 设备 | 允许应用访问 KVM 相关设备 |
| `compose.override` | 高危运行时覆盖 | 允许应用通过 Compose Override 覆盖最终运行时配置 |

**示例：**

```yaml
package: cloud.lazycat.app.demo-app
version: 0.0.1
name: Demo App
description: Demo application
author: Demo Team
license: MIT
homepage: https://example.com
min_os_version: 1.3.8
locales:
  zh-CN:
    name: "示例应用"
    description: "示例应用描述"

permissions:
  required:
    - net.internet
    - document.read
  optional:
    - document.write
    - device.dri.render
```

---

# 部署参数规范

## lzc-deploy-params.yml 规范

部署参数文件用于定义用户在安装应用时需要配置的参数（安装向导）。

### 参数类型

| 类型 | 描述 | 示例 |
|------|------|------|
| `string` | 字符串 | 域名, 应用名称, 日志级别 |
| `secret` | 敏感字符串 | API Token, 密码, JWT Secret |
| `bool` | 布尔值 | 启用/禁用功能 |
| `lzc_uid` | LazyCat 用户 ID | 绑定盒子用户 |

### 字段说明

| 字段名 | 类型 | 描述 |
|--------|------|------|
| `id` | `string` | 参数 ID（推荐使用小写英文+下划线） |
| `type` | `string` | 参数类型：`bool`、`lzc_uid`、`string`、`secret` |
| `name` | `string` | 参数名称（英文） |
| `description` | `string` | 参数描述（英文） |
| `default_value` | `string` | 默认值，支持 `$random(len=5)` |
| `optional` | `bool` | 是否可选 |
| `hidden` | `bool` | 字段生效但不在界面中渲染 |

**⚠️ 关键规则：**
- `params.id`: 推荐使用**小写英文+下划线**（如 `yuque_token`, `enable_auto_sync`）
- `params.name/description`: 必须是英文
- `locales`: 提供多语言翻译，key 必须匹配 params.id
- 不要生成 `placeholder`、`regex`、`regex_message`、`min`、`max`
- 不要生成 `type: number`

**示例：**

```yaml
params:
  - id: workspace_name
    type: string
    name: "workspace name"
    description: "Workspace name shown in the application"
    default_value: "my-workspace"
    optional: false

  - id: yuque_token
    type: secret
    name: "yuque token"
    description: "API token for Yuque"
    optional: true

  - id: owner_uid
    type: lzc_uid
    name: "owner user"
    description: "LazyCat user who will own the workspace"
    optional: false

locales:
  zh:
    workspace_name:
      name: "工作区名称"
      description: "应用中展示的工作区名称"
    yuque_token:
      name: "语雀 Token"
      description: "语雀 API Token"
    owner_uid:
      name: "所属用户"
      description: "绑定到该工作区的 LazyCat 用户"
```

---

# 构建配置规范

## lzc-build.yml 规范

构建配置文件用于定义如何构建 LazyCat 应用包（.lpk）。

### LPK v2 格式（默认，推荐）

**要求：**
- lzcos v1.5.0+
- lzc-cli v2.0.0+ (`npm install -g @lazycatcloud/lzc-cli@2.0.0`)

**输出：** Tar 格式的 LPK v2，包含 `package.yml`、`manifest.yml`、可选的 `content.tar.gz`、可选的 `images/` 和 `images.lock`。

### 字段说明

| 字段名 | 类型 | 描述 |
|--------|------|------|
| `manifest` | `string` | 指定 manifest.yml 文件路径（必需） |
| `pkgout` | `string` | lpk 包的输出路径（必需） |
| `icon` | `string` | 应用图标路径，必须是 512x512 PNG 格式（必需） |
| `contentdir` | `string` | 额外内容目录（可选）；未配置或显式空值时不会生成内容归档 |
| `pkg_id` | `string` | 可选；`LPK v2` 下覆盖最终 `package.yml.package` 的值 |
| `pkg_name` | `string` | 可选；`LPK v2` 下覆盖最终 `package.yml.name` 的值 |
| `envs` | `[]string` | 可选；构建期变量列表，支持 `KEY=VALUE` 字符串数组 |
| `images` | `map[string]ImageBuildConfig` | 可选；`LPK v2` 下用于产出 `embed:<alias>` 镜像引用 |
| `compose_override` | `map` | 覆盖不支持的 Docker Compose 参数（可选） |

### Images 配置 (LPK v2)

用于在打包阶段通过 Dockerfile 构建镜像，并生成 LPK v2 所需的 `images/` 与 `images.lock`。

| 字段名 | 类型 | 描述 |
|--------|------|------|
| `dockerfile` | `string` | Dockerfile 文件路径，与 `dockerfile-content` 二选一 |
| `dockerfile-content` | `string` | Dockerfile 内容，与 `dockerfile` 二选一 |
| `context` | `string` | 构建上下文目录 |
| `upstream-match` | `string` | 按前缀匹配上游镜像，默认 `registry.lazycat.cloud` |

**示例：**

```yaml
# lzc-build.yml
manifest: ./lzc-manifest.yml
pkgout: ./
icon: ./icon.png

# 可选：内嵌镜像构建
images:
  app-runtime:
    dockerfile: ./Dockerfile
    context: .
```

在 `lzc-manifest.yml` 中引用：
```yaml
services:
  app:
    image: embed:app-runtime
```

### 文件组织约定

推荐项目结构（LPK v2）：
```
.
├── lzc-build.yml          # 默认构建配置（release）
├── lzc-build.dev.yml      # 开发态覆盖配置（可选）
├── package.yml            # 静态包元数据（LPK v2 必需）
├── lzc-manifest.yml       # 应用运行结构定义
├── icon.png               # 应用图标（512x512 PNG）
├── Dockerfile             # 内嵌镜像构建（可选）
└── content/               # 额外内容目录（可选）
```

**示例：**

```yaml
# lzc-build.yml
manifest: ./lzc-manifest.yml
pkgout: ./
icon: ./icon.png

# 可选：开发态覆盖
# lzc-build.dev.yml
pkg_id: cloud.lazycat.app.demo-app.dev
contentdir:
envs:
  - DEV_MODE=1

# 可选：覆盖不支持的参数
compose_override:
  services:
    app:
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock
      devices:
        - /dev/ttyUSB0:/dev/ttyUSB0
```

---

# 高级功能参考

## 1. Secondary Domains (多域名支持)

允许一个应用使用多个域名，每个域名可以路由到不同的服务。

```yaml
application:
  subdomain: myapp  # 主域名
  secondary_domains:
    - portainer  # 次级域名
    - whoami
```

**域名格式：**
- 主域名：`myapp.xxx.heiyu.space`
- 次级域名：`portainer.xxx.heiyu.space`, `whoami.xxx.heiyu.space`

**配合 APP Proxy 使用：**

```yaml
services:
  app-proxy:
    image: registry.lazycat.cloud/app-proxy:v0.1.0
    setup_script: |
      cat <<'EOF' > /etc/nginx/conf.d/default.conf
      server {
         server_name  myapp.*;
         location / {
            proxy_pass http://web:80;
         }
      }
      server {
         server_name  portainer.*;
         location / {
            proxy_pass http://portainer:9000;
         }
      }
      EOF
```

---

## 2. OIDC 集成

LazyCat 支持 OIDC (OpenID Connect) 用于单点登录。

```yaml
application:
  oidc_redirect_path: /auth/oidc.callback

services:
  app:
    environment:
      - OIDC_CLIENT_ID=${LAZYCAT_AUTH_OIDC_CLIENT_ID}
      - OIDC_CLIENT_SECRET=${LAZYCAT_AUTH_OIDC_CLIENT_SECRET}
      - OIDC_AUTH_URI=${LAZYCAT_AUTH_OIDC_AUTH_URI}
      - OIDC_TOKEN_URI=${LAZYCAT_AUTH_OIDC_TOKEN_URI}
      - OIDC_USERINFO_URI=${LAZYCAT_AUTH_OIDC_USERINFO_URI}
      - OIDC_ISSUER_URI=${LAZYCAT_AUTH_OIDC_ISSUER_URI}
```

**可用的 OIDC 环境变量：**
- `LAZYCAT_AUTH_OIDC_CLIENT_ID` - 客户端 ID
- `LAZYCAT_AUTH_OIDC_CLIENT_SECRET` - 客户端密钥
- `LAZYCAT_AUTH_OIDC_ISSUER_URI` - Issuer URI
- `LAZYCAT_AUTH_OIDC_AUTH_URI` - 授权端点
- `LAZYCAT_AUTH_OIDC_TOKEN_URI` - Token 端点
- `LAZYCAT_AUTH_OIDC_USERINFO_URI` - 用户信息端点

---

## 3. 运行时环境变量

LazyCat 系统自动注入的环境变量：

| 环境变量 | 描述 |
|---------|------|
| `LAZYCAT_APP_ID` | 应用唯一标识 |
| `LAZYCAT_APP_NAME` | 应用名称 |
| `LAZYCAT_SUBDOMAIN` | 子域名 |
| `LAZYCAT_BOX_DOMAIN` | 盒子域名 |
| `LAZYCAT_PUBLIC_URL` | 完整访问 URL |
| `LAZYCAT_APP_DEPLOY_UID` | 多实例用户 ID |
| `LAZYCAT_APP_SERVICE_NAME` | 当前服务名称 |
| `LAZYCAT_BOX_NAME` | 盒子名称 |
| `LAZYCAT_APP_DEPLOY_ID` | 实例 ID (v1.3.8+) |

---

## 4. 模板函数

### 4.1 内部服务模板 ({{.INTERNAL.xxx}})

自动生成内部服务的敏感配置：

```yaml
services:
  postgres:
    environment:
      - POSTGRES_PASSWORD={{.INTERNAL.db_password}}
```

### 4.2 用户配置模板 ({{.U.xxx}})

引用用户在安装时配置的参数：

```yaml
services:
  app:
    environment:
      - JWT_SECRET={{.U.jwt_secret_key}}
```

### 4.3 稳定密钥生成 (stable_secret)

生成稳定的密钥，无需用户输入：

```yaml
services:
  app:
    environment:
      - API_KEY={{ stable_secret "api_key_v1"}}
      - ENCRYPTION_KEY={{ stable_secret "encryption_seed"}}
```

**特性：**
- 同一应用同一种子 → 结果相同
- 不同应用同一种子 → 结果不同
- 微服恢复出厂设置 → 结果改变

### 4.4 系统参数 (.S)

```yaml
services:
  app:
    environment:
      - BOX_NAME={{.S.BoxName}}
      - OS_VERSION={{.S.OSVersion}}
      - DEPLOY_UID={{.S.DeployUID}}
      - IS_MULTI_INSTANCE={{.S.IsMultiInstance}}
```

---

## 5. Service Domain 命名规则

### 单实例

```
${service_name}.${appid}.lzcapp
```

示例：`postgres.cloud.lazycat.app.myapp.lzcapp`

### 多实例

```
${userId}.${service_name}.${appid}.lzcapp
```

示例：`user123.postgres.cloud.lazycat.app.myapp.lzcapp`

### 特殊域名

- `host.lzcapp` - Docker bridge，访问宿主机服务
- `_outbound` - 默认出口 IP
- `_gateway` - 网络网关

---

## 6. Public Path 排除语法

使用 `!` 前缀排除特定路径：

```yaml
application:
  public_path:
    - /
    - !/admin  # 排除 /admin 路径
    - !/api/private
```

---

## 7. Multi-instance (多实例)

每个用户启动独立的应用容器实例：

```yaml
application:
  multi_instance: true
```

**特点：**
- 每个用户独立容器
- 数据天然隔离
- 无需应用处理多用户权限
- 占用更多内存资源

**域名差异：**
- 单实例：`service.appid.lzcapp`
- 多实例：`userId.service.appid.lzcapp`

---

## 8. APP Proxy

官方维护的 OpenResty 路由代理，用于复杂路由和请求日志。

**镜像：** `registry.lazycat.cloud/app-proxy:v0.1.0`

### 模式 1: 环境变量

```yaml
services:
  app-proxy:
    image: registry.lazycat.cloud/app-proxy:v0.1.0
    environment:
      - UPSTREAM=http://whoami:80
      - BASIC_AUTH_HEADER=Basic dXNlcjpwYXNzd29yZA==
      - REMOVE_REQUEST_HEADERS=Origin;Host;
```

### 模式 2: setup_script

```yaml
services:
  app-proxy:
    image: registry.lazycat.cloud/app-proxy:v0.1.0
    setup_script: |
      cat <<'EOF' > /etc/nginx/conf.d/default.conf
      server {
         server_name  myapp.*;
         location / {
            proxy_pass http://web:80;
         }
      }
      EOF
```

---

## 9. Dockerd 支持

使用 `sysbox-runc` 运行时支持在容器内运行 Docker：

```yaml
services:
  dockge:
    image: louislam/dockge:latest
    runtime: sysbox-runc  # 必需
    binds:
      - /lzcapp/var/stacks:/opt/stacks
      - /data/playground/docker.sock:/var/run/docker.sock
```

**compose_override 配置：**

```yaml
# lzc-build.yml
compose_override:
  services:
    dockge:
      volumes:
        - /data/playground/docker.sock:/var/run/docker.sock
```

---

## 10. 保留服务名称

以下服务名称为系统保留，不能使用：

- ❌ `app` - 系统保留

**解决方案：** 使用 `app-service`, `web`, `backend` 等替代名称。

---

**文档版本：** 基于懒猫微服 v1.4.1+

**最后更新：** 2025-12-26
