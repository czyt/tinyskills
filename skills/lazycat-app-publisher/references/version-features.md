# LazyCat OS Version Features Reference

This document maps LazyCat OS versions to their features, helping you determine `min_os_version` requirements.

## Version-Feature Matrix

| Feature | Minimum Version | Notes |
|---------|----------------|-------|
| `services.[].healthcheck` | v1.4.1 | 100% docker-compose compatible |
| `services.[].health_check` | Pre-v1.4.1 | ⚠️ Deprecated, use `healthcheck` |
| `compose_override` | v1.3.0 | For unsupported docker-compose params |
| `application.upstreams` | v1.3.8 | Recommended over `routes` |
| `services.[].mem_limit` | v1.3.8 | Memory limits |
| `services.[].shm_size` | v1.3.8 | Shared memory size |
| `sysbox-runc` runtime | v1.3.8 | Legacy isolated runtime capability; long-lived Docker/system environments should use LightOS |
| Multi-entry points | v1.4.3 | `application.entries` |
| `api_auth_token` | v1.4.3 | For external API access |
| `disable_trim_location` | v1.3.9 | Keep URL path in upstream |
| `/lzcapp/documents` | v1.5.0 | Replaces `/lzcapp/document` |
| **LPK v2 / `package.yml`** | **v1.5.0** | **New tar-based format, static metadata split** |
| **lzc-cli v2.0.0+** | **v1.5.0** | **Required for LPK v2** |
| Network isolation | v1.3.0 | Cross-app via `$service.$appid.lzcapp` |
| `permissions` in package.yml | v1.5.0 | Declarative permission system |
| `ext_config.enable_document_access` | v1.5.0 | Enables deprecated `/lzcapp/run/mnt/home` compatibility path; v1.7.0+ also requires administrator authorization |
| **App Interconnect (`.lzcx`)** | **v1.5.2** | **应用间 HTTP 访问，`app.<pkg>.lzcx` 地址** |
| **`lzcapp.self_delegate` / `lzcapp.user_delegate`** | **v1.5.2** | **应用间访问权限声明** |
| **`import_resources`** | **v1.5.2** | **`package.yml` 中声明导入 Skill/MCP 资源** |
| **`resource_exports`** | **v1.5.2** | **`lzc-build.yml` 中配置 Skill/MCP 导出** |
| **Skill / MCP export** | **v1.5.2** | **应用通过 `resources/` 目录提供 Skill/MCP** |
| **`run_as` (UID/GID + owner 映射)** | **v1.6.0+** | **容器数字 UID/GID + `/lzcapp` 持久目录 owner 映射** ⭐ |
| **`hidden_from_launcher`** | **v1.5.3** | **从启动器隐藏应用入口（不影响访问地址/权限/部署）** |
| **`user.notify` 权限** | **v1.6.0** | **向用户发送通知，注入 `/lzcinit/notify-send` 二进制** |
| **`fuse.mount` 权限** | **v1.6.1** | **注入 `/lzcinit/fusermount3` 并将 `/lzcinit` 加入 `PATH`** |
| **`vt.display` + `application.vt`** | **v1.6.1** | **物理显示器 VT；所有 service 必须使用 `runc`** |
| **文件选择器拦截** | **v1.5.0+** | **应用商店强制要求：有上传/下载功能必须接入** ⭐ |

---

## LPK Format Versions

### LPK v2 (Default, Recommended)

**Requirements:**
- lzcos v1.5.0+
- lzc-cli v2.0.0+ (`npm install -g @lazycatcloud/lzc-cli@2.0.0`)

**File Structure:**
```
app.lpk (tar format)
├── manifest.yml          # Runtime structure only
├── package.yml           # Static metadata (REQUIRED)
├── content.tar.gz        # Optional content
├── images/               # Embedded images (optional)
├── images.lock           # Image lock file
└── META/                 # Archive metadata
```

**Key Changes:**
- Static metadata (`package`, `version`, `name`, etc.) moved to `package.yml`
- `lzc-manifest.yml` contains only runtime structure
- Tar-based format (was zip in v1)
- Support for embedded images via `images/` and `images.lock`

### LPK v1 (Legacy)

**Compatible with:** All versions

**File Structure:**
```
app.lpk (zip format)
├── manifest.yml          # Contains both static and runtime data
├── content.tar.gz        # Optional content
└── META/                 # Archive metadata
```

---

## Detailed Changelog

### v1.5.0 (Recommended)

**New Features:**
- **LPK v2 format**: Tar-based, requires `package.yml`, supports embedded images
- **Declarative permissions**: `permissions` field in `package.yml`
- **New document path**: `/lzcapp/documents` (plural)
- **Private app documents**: `document.private` + `/lzcapp/documents/<uid>`
- **lzc-cli v2.0.0+**: New `project` workflow commands

**Compatibility Changes:**
- `/lzcapp/document` and `/lzcapp/run/mnt/home` are deprecated
- Document access root path is now `/lzcapp/documents`
- `ext_config.enable_document_access` only enables deprecated `/lzcapp/run/mnt/home`; v1.7.0+ also requires administrator authorization
- Static metadata must be in `package.yml` (not `lzc-manifest.yml`)

**Migration to LPK v2:**
```yaml
# Before (LPK v1) - lzc-manifest.yml
package: cloud.lazycat.app.myapp
version: 1.0.0
name: MyApp
description: "My app"
application:
  subdomain: myapp

# After (LPK v2) - package.yml
package: cloud.lazycat.app.myapp
version: 1.0.0
name: MyApp
description: "My app"

# After (LPK v2) - lzc-manifest.yml
application:
  subdomain: myapp
```

**Path Migration:**
```yaml
# Before v1.5.0
binds:
  - /lzcapp/document:/data/documents

# After v1.5.0: package.yml
permissions:
  required:
    - document.private

# Application code writes user-managed files to:
# /lzcapp/documents/<uid>
```

### v1.4.3

**New Features:**
- `clientfs` support
- Launcher Multiple Entrypoints (`application.entries`)
- `hc api_auth_token` for external API access

### v1.4.2

**Compatibility Changes:**
- `services.xx.user` must be string: use `"1000"` not `1000`
- `services.xxx.environment` cannot be empty

**Example:**
```yaml
# ❌ Wrong (will error in v1.4.2+)
services:
  app:
    user: 1000
    environment: []

# ✅ Correct
services:
  app:
    user: "1000"
    # Omit environment if empty, or provide values
```

### v1.4.1

**Key Change:** `healthcheck` field for services

```yaml
# ✅ v1.4.1+ format (recommended)
services:
  postgres:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

# ⚠️ Pre-v1.4.1 format (deprecated)
services:
  postgres:
    health_check:
      test: ["CMD", "pg_isready"]
      start_period: 30  # No unit suffix
```

### v1.3.8

**Major Features:**
- Application deployment mechanism (`manifest render`)
- `LAZYCAT_DEPLOY_ID` environment variable
- TCP ingress forwarding 80/443
- File handler wildcard support
- `mem_limit` and `shm_size` for services
- `UpstreamConfig` with domain prefix routing
- `sysbox-runc` runtime

**Important:** This is the recommended minimum version for modern apps.

### v1.6.0

**New Features:**
- **`run_as`**: Container UID/GID with `/lzcapp` persistent directory owner mapping
- `application.run_as` for the main app container, `services.<name>.run_as` per-service
- Only accepts numeric UID/GID (`1000` or `"1000:1000"`)
- Cannot be used with `user` or `setup_script` simultaneously
- Each service can have its own `run_as` with independent owner views
- **`user.notify` permission**: Allow apps to send user notifications via `/lzcinit/notify-send` binary

**Required for:**
- Multi-UID/GID applications needing persistent directory ownership
- Apps needing to send user notifications

### v1.5.3

**New Features:**
- **`hidden_from_launcher`**: Hide app entry from launcher (in `package.yml`)
- Only affects launcher display, does not change app access URL, permissions, or deployment behavior

### v1.5.2+

### v1.5.2

**New Features:**
- **App Interconnect**: `.lzcx` address for app-to-app HTTP access
- **Delegate permissions**: `lzcapp.self_delegate` (access self) and `lzcapp.user_delegate` (access others)
- **`X-HC-USER-TICKET`**: User ticket injected by ingress for auth
- **`import_resources`**: Declare Skill/MCP resource imports in `package.yml`
- **`resource_exports`**: Configure Skill/MCP exports in `lzc-build.yml`
- **Skill/MCP directory**: Standard `resources/skills/<id>/SKILL.md` and `resources/mcp-providers/<id>/mcp.yml`
- **New permissions**: `device.dri.master`, `device.block`, `fuse.mount`, `net.admin`, `appvar.other.read`, `appvar.other.write`, `power.shutdown.inhibit`, `lightos.use`, `lightos.manage`

> `fuse.mount` permission id may appear in older schemas, but the injected `fusermount3` compatibility contract requires lzcos v1.6.1+.

**Required for:**
- App-to-app HTTP communication (`app.<pkg>.lzcx`)
- Exposing/consuming Skill and MCP resources

### v1.6.1

**New Features:**
- `fuse.mount` injects `/lzcinit/fusermount3` and puts `/lzcinit` on `PATH` for standard FUSE clients.
- `vt.display` plus `application.vt: true` enables the app physical-display VT and `/lzcinit/vt.active`.
- VT apps cannot use `sysbox-runc`; every service must use the default `runc` runtime.

### v1.3.0

**Major Features:**
- `compose_override` support
- Internationalization/localization
- Network isolation between applications

---

## Setting min_os_version

### Recommendation

```yaml
# Recommended baseline for LPK v2
min_os_version: 1.5.0  # 使用更高版本特性时继续上调
```

### Decision Guide

| If Using | Set min_os_version |
|----------|-------------------|
| Basic manifest only (LPK v1) | `1.3.0` |
| LPK v2 / `package.yml` | `1.5.0` |
| `upstreams`, `mem_limit`, `shm_size` | `1.3.8` |
| `healthcheck` (services) | `1.4.1` |
| Multi-entry points | `1.4.3` |
| `/lzcapp/documents` | `1.5.0` |
| App Interconnect (`.lzcx`) | `1.5.2` |
| Skill/MCP `import_resources` | `1.5.2` |
| Skill/MCP `resource_exports` | `1.5.2` |
| Delegate permissions | `1.5.2` |
| `run_as` (UID/GID owner 映射) | `1.6.0` |
| `hidden_from_launcher` | `1.5.3` |
| `user.notify` 权限 | `1.6.0` |
| `fuse.mount` helper contract | `1.6.1` |
| Physical-display VT | `1.6.1` |
| 文件选择器拦截（应用商店强制） | `1.5.0` |

---

## Compatibility Check

### v1.4.1+ healthcheck Migration

If upgrading from pre-v1.4.1:

```yaml
# Old format
health_check:
  test: ["CMD", "pg_isready"]
  start_period: 30

# New format (v1.4.1+)
healthcheck:
  test: ["CMD-SHELL", "pg_isready"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
```

**Key changes:**
1. Field name: `health_check` → `healthcheck`
2. Add unit suffix: `30` → `30s`
3. Use `CMD-SHELL` for better compatibility

### v1.5.0 Path Migration

For applications accessing user documents:

```yaml
# Add document.private to package.yml, then update application paths:
# /lzcapp/document → /lzcapp/documents/<uid>

# Only legacy /lzcapp/run/mnt/home compatibility uses:
# ext_config.enable_document_access: true
```

## v1.6.3 用户组请求头

- 新增 `X-HC-User-Groups` 请求头（lzcos v1.6.3+）：JSON 数组，每个元素 `{id, name}`——`id` 是稳定组 UUID（明文），`name` 是 UTF-8 组名的标准 Base64 编码（保留 `=` 填充）。应用先 JSON 解析再对各 `name` 做 Base64 解码。
- 未加入任何组的用户不发送该头；`lzc-ingress` 会清除调用方传入的同名头再按已认证用户设置。
- 管理员变更成员/组名后，每次新请求即时反映，无需用户重新登录。
- 用户组目前无正式管理页面；测试期管理员手动进系统设置站点 `/sys/debug/` → `user-groups` 创建组并维护成员。
- 应用用 `id` 绑定权限规则（重命名组不改 `id`），`name` 仅用于展示。

## v1.6.2 兼容性与动态图标

- 动态启动器图标要求 `min_os_version: 1.6.2`，详见 [dynamic-icon.md](dynamic-icon.md)。
- v1.6.2 将 `exec://` 路由声明的本地端口纳入自动健康监测；脚本必须在该端口提供服务，详见 [healthcheck.md](healthcheck.md)。
- v1.6.1 起取消默认挂载 `/dev/fuse`；FUSE 应声明 `fuse.mount` 并使用注入的 `/lzcinit/fusermount3`。
