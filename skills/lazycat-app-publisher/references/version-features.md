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
| `sysbox-runc` runtime | v1.3.8 | For privileged containers (dockerd, systemd) |
| Multi-entry points | v1.4.3 | `application.entries` |
| `api_auth_token` | v1.4.3 | For external API access |
| `disable_trim_location` | v1.3.9 | Keep URL path in upstream |
| `/lzcapp/documents` | v1.5.0 | Replaces `/lzcapp/document` |
| Network isolation | v1.3.0 | Cross-app via `$service.$appid.lzcapp` |

---

## Detailed Changelog

### v1.5.0 (Unreleased)

**Compatibility Changes:**
- `/lzcapp/document` and `/lzcapp/run/mnt/home` are deprecated
- Document access root path is now `/lzcapp/documents`
- Applications needing document access must set `ext_config.enable_document_access`

**Migration:**
```yaml
# Before v1.5.0
binds:
  - /lzcapp/document:/data/documents

# After v1.5.0
binds:
  - /lzcapp/documents:/data/documents
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

### v1.3.0

**Major Features:**
- `compose_override` support
- Internationalization/localization
- Network isolation between applications

---

## Setting min_os_version

### Recommendation

```yaml
# Recommended for most modern applications
min_os_version: 1.3.8
```

### Decision Guide

| If Using | Set min_os_version |
|----------|-------------------|
| Basic manifest only | `1.3.0` |
| `upstreams`, `mem_limit`, `shm_size` | `1.3.8` |
| `healthcheck` (services) | `1.4.1` |
| Multi-entry points | `1.4.3` |
| `/lzcapp/documents` | `1.5.0` |

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
# Add to manifest for v1.5.0+
ext_config:
  enable_document_access: true

# Update paths
# /lzcapp/document → /lzcapp/documents
```