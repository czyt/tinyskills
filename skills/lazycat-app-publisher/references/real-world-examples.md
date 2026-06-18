# Real-World LazyCat Application Examples

This file contains actual LazyCat application examples from the community, showing advanced patterns and real-world usage.

## 1. Vaultwarden (Password Manager with Advanced Features)

### Original Docker Compose Concept
```yaml
services:
  vaultwarden:
    image: vaultwarden/server:latest
    volumes:
      - ./data:/data
    ports:
      - "80:80"
```

### LazyCat Implementation
```yaml
# lzc-manifest.yml
name: Vaultwarden+
package: community.lazycat.app.vaultwarden
version: 1.34.3
min_os_version: 1.3.8
description: "Vaultwarden with auto backup and cloud sync"
homepage: https://github.com/dani-garcia/vaultwarden
author: dani-garcia

application:
  subdomain: vaultwarden
  background_task: true
  public_path:
    - /
  upstreams:
    - location: /
      backend: http://vaultwarden:80/

services:
  vaultwarden:
    image: registry.lazycat.cloud/czyt/vaultwarden/server:c660a371ce9cf96b
    binds:
      - /lzcapp/var/data:/data/

# Optional backup service (conditional)
{{ if .U.enable_auto_backup }}
  vaultwarden-backup:
    image: registry.lazycat.cloud/czyt/czyt/rclone-backup:401f26b4c063ff78
    environment:
      - BACKUP_FOLDER_NAME=data
      - BACKUP_FOLDER_PATH=/data
      - RCLONE_GLOBAL_FLAG={{.U.rclone_global_flag}}
      - CRON={{.U.backup_cron}}
      - ZIP_ENABLE={{.U.enable_backup_compression}}
      - ZIP_PASSWORD={{.U.backup_compression_password}}
      - ZIP_TYPE={{.U.backup_compression_type}}
      - BACKUP_FILE_SUFFIX=%Y%m%d
      - BACKUP_KEEP_DAYS={{.U.backup_keep_days}}
      - BACKUP_KEEP_COUNT={{.U.backup_keep_count}}
      - TIMEZONE={{.U.time_zone_for_backup}}
      - RCLONE_REMOTE_NAME={{.U.rclone_remote_name}}
      - RCLONE_REMOTE_DIR={{.U.rclone_remote_dir}}
    binds:
      - /lzcapp/var/data:/data/
      - /lzcapp/var/config:/config/
{{ end }}

locales:
  zh:
    name: "Vaultwarden+"
    description: "Vaultwarden增强版，支持自动加密备份和上传到多个云端目标"
  en:
    name: "Vaultwarden+"
    description: "Vaultwarden Plus with auto encrypted backup to cloud"
```

**Key Features:**
- Uses `upstreams` for internal routing
- Conditional services with template syntax
- Multi-language support
- Background task mode

---

## 2. Lucky (Network Toolkit with Host Network)

### Original Docker Compose Concept
```yaml
services:
  lucky:
    image: gdy666/lucky:latest
    volumes:
      - ./goodluck:/app/conf
    network_mode: host
    restart: always
```

### LazyCat Implementation
```yaml
# lzc-manifest.yml
name: Lucky
package: cloud.lazycat.app.lucky
version: 2.24.0
min_os_version: 1.3.8
description: "软硬路由公网神器"
homepage: https://lucky666.cn
author: gdy666

application:
  subdomain: lucky
  background_task: true
  public_path:
    - /
  upstreams:
    - location: /
      backend: http://host.lzcapp:16601/

services:
  lucky:
    user: root
    image: registry.lazycat.cloud/czyt/gdy666/lucky:39eb30b5c305a7b6
    binds:
      - /lzcapp/var/goodluck:/app/conf
    network_mode: host

locales:
  zh:
    name: "Lucky"
    description: "软硬路由公网神器"
  en:
    name: "Lucky"
    description: "Powerful network kit for self-hosting"
```

**Key Features:**
- `network_mode: host` for direct network access
- `user: root` for elevated permissions
- Uses `upstreams` to route to host network service
- Background task mode

---

## 3. Cloudflared Web (Tunnel with Environment Variables)

### Original Docker Compose Concept
```yaml
services:
  cloudflared:
    image: wisdomsky/cloudflared-web:latest
    volumes:
      - ./config:/config
    ports:
      - "14333:14333"
    environment:
      - PROTOCOL=http2
```

### LazyCat Implementation
```yaml
# lzc-manifest.yml
name: Cloudflared
package: cloud.lazycat.app.cloudfalredweb
version: 2025.11.1
description: "Cloudflare Tunnel Web Interface"
homepage: https://github.com/WisdomSky/Cloudflared-web
author: WisdomSky

application:
  subdomain: cloudfalredweb
  background_task: true
  routes:
    - /=http://host.lzcapp:14333/

services:
  cloudflaredweb:
    network_mode: host
    image: registry.lazycat.cloud/czyt/wisdomsky/cloudflared-web:7aa34bb82e1f6c59
    binds:
      - /lzcapp/var/config:/config
    environment:
      - PROTOCOL={{.U.protocol}}

locales:
  zh:
    name: "Cloudflared"
    description: "Cloudflare Tunnel 提供了一种安全的方式，可以将 Web服务器安全地公开到互联网上"
  en:
    name: "Cloudflared"
    description: "Cloudflare Tunnel client (formerly Argo Tunnel)"
```

**Key Features:**
- Uses `routes` instead of `upstreams`
- User-configurable environment variables
- Simple single-service structure

---

## 4. Blinko (Multi-Service with Health Checks)

### Original Docker Compose Concept
```yaml
services:
  blinko:
    image: blinkospace/blinko:latest
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/blinko
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=blinko
    volumes:
      - ./db:/var/lib/postgresql/data
```

### LazyCat Implementation
```yaml
# lzc-manifest.yml
name: Blinko
package: lazycat.community.app.blinko
min_os_version: 1.3.8
version: 1.7.1
description: "An open-source, self-hosted personal AI note tool"
homepage: https://github.com/blinkospace/blinko
author: blinkospace

application:
  subdomain: blinko
  background_task: true
  public_path:
    - /
  upstreams:
    - location: /
      backend: http://blinko-website:1111/

services:
  blinko-website:
    image: docker.1ms.run/blinkospace/blinko:1.7.1
    environment:
      - NODE_ENV=production
{{if .U.use_custom_domain}}
      - NEXTAUTH_URL=https://${.U.custom_domain}
{{else}}
      - NEXTAUTH_URL=https://${LAZYCAT_APP_DOMAIN}
{{end}}
      - NEXT_PUBLIC_BASE_URL=https://${LAZYCAT_APP_DOMAIN}
      - NEXTAUTH_SECRET=3VAQCMUjWZXk5+0wyQCtLAbmbFXteAh3DrC3TAy0zJA=
      - DATABASE_URL=postgresql://postgres:postgres@blinko_db:5432/blinko

    health_check:
      test:
        - CMD-SHELL
        - curl -f http://blinko-website:1111/
      start_period: 60s

    depends_on:
      - blinko_db

  blinko_db:
    container_name: blinko_db
    image: registry.lazycat.cloud/czyt/library/postgres:bc75bb4e26564157
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=blinko
      - TZ=Asia/Shanghai
    binds:
      - /lzcapp/var/db:/var/lib/postgresql/data
    health_check:
      test:
        - CMD-SHELL
        - pg_isready -U postgres -d blinko
      start_period: 90s
```

**Key Features:**
- Template conditionals for custom domains
- Health checks with custom commands
- Service dependencies
- Timezone configuration
- Internal database with persistent storage

---

## 5. Nextcloud (Complex Multi-Service)

### Original Docker Compose Concept
```yaml
services:
  nextcloud:
    image: nextcloud:latest
    ports:
      - "8080:80"
    environment:
      MYSQL_PASSWORD: nextcloud
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
      MYSQL_HOST: db
    volumes:
      - nextcloud_data:/var/www/html
    depends_on:
      - db

  db:
    image: mariadb:10.6
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_PASSWORD: nextcloud
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
    volumes:
      - db_data:/var/lib/mysql
```

### LazyCat Implementation
```yaml
# lzc-manifest.yml
name: Nextcloud
package: cloud.lazycat.app.nextcloud
version: 1.0.0
description: "Nextcloud File Hosting"
homepage: https://nextcloud.com
author: Nextcloud

application:
  subdomain: nextcloud
  routes:
    - /=http://nextcloud.cloud.lazycat.app.nextcloud.lzcapp:8080

services:
  nextcloud:
    image: nextcloud:latest
    environment:
      - MYSQL_PASSWORD=nextcloud
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_HOST=db
    binds:
      - /lzcapp/var/nextcloud:/var/www/html
    depends_on:
      - db
    cpu: 1500
    mem_limit: 1024M

  db:
    image: mariadb:10.6
    environment:
      - MYSQL_ROOT_PASSWORD=rootpassword
      - MYSQL_PASSWORD=nextcloud
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
    binds:
      - /lzcapp/var/mariadb:/var/lib/mysql
    cpu: 1000
    mem_limit: 512M
```

---

## 6. GitLab with SSH (Ingress Configuration)

### LazyCat Implementation
```yaml
# lzc-manifest.yml
name: GitLab CE
package: cloud.lazycat.app.gitlab-ce
version: 1.0.0
description: "GitLab Community Edition"
homepage: https://gitlab.com
author: GitLab Inc.

application:
  subdomain: gitlab
  routes:
    - /=http://gitlab.cloud.lazycat.app.gitlab-ce.lzcapp:80
    - /api/=http://gitlab.cloud.lazycat.app.gitlab-ce.lzcapp:80
  ingress:
    - protocol: tcp
      port: 22
      service: gitlab
      description: "SSH for Git operations"

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    environment:
      - GITLAB_OMNIBUS_CONFIG=external_url 'http://gitlab.${LAZYCAT_BOX_DOMAIN}'
    binds:
      - /lzcapp/var/config:/etc/gitlab
      - /lzcapp/var/logs:/var/log/gitlab
      - /lzcapp/var/data:/var/opt/gitlab
    shm_size: '256m'
    cpu: 2000
    mem_limit: 4096M
```

**Key Features:**
- Multiple routes for different paths
- TCP ingress for SSH (non-HTTP service)
- Shared memory configuration
- Resource limits

---

## 7. Ask4Me (Help Page Redirect + Injects + Conditional Template)

### Key Patterns Demonstrated
- **404 → 帮助页自动跳转**：通过 `injects` response 阶段拦截 404，重定向到静态帮助页
- **静态文件服务**：`file:///lzcapp/pkg/content/web/index.html` 直接从包内容提供 HTML
- **public_path 必须同时包含 `/` 和 `/help`**：否则 `/help` 路径无法访问
- **条件模板带 fallback**：`{{if .U.base_url}}...{{else}}https://{{.S.AppDomain}}{{end}}`
- **usage 字段为纯字符串**：正确格式，不使用嵌套结构

### LazyCat Implementation
```yaml
application:
  subdomain: ask4me
  upstreams:
    - location: /help
      backend: file:///lzcapp/pkg/content/web/index.html
    - location: /
      backend: http://ask4me:8080/
  injects:
    - id: redirect-404-to-help
      on: response
      auth_required: false
      when:
        - "/*"
      do: |
        if (ctx.status === 404) {
          ctx.response.send(302, "", { location: "/help" });
          return;
        }
  public_path:
    - /
    - /help

services:
  ask4me:
    # easychen/ask4me:0.2.4
    image: registry.lazycat.cloud/czyt/easychen/ask4me:090e4b934df935e8
    environment:
      - ASK4ME_BASE_URL={{if .U.base_url}}{{.U.base_url}}{{else}}https://{{.S.AppDomain}}{{end}}
      - ASK4ME_API_KEY={{.U.api_key}}
      - ASK4ME_SERVERCHAN_SENDKEY={{.U.serverchan_sendkey}}
      - ASK4ME_APPRISE_URLS={{.U.apprise_urls}}
      - ASK4ME_APPRISE_BIN={{.U.apprise_bin}}
      - ASK4ME_SQLITE_PATH=/data/ask4me.db
      - ASK4ME_LISTEN_ADDR=:8080
    binds:
      - /lzcapp/var/data:/data

usage: |
  Ask4Me forwards your questions to an AI backend and delivers answers via notification channels (ServerChan or Apprise).

  1. Set your API key and at least one notification channel (ServerChan or Apprise) during deployment.
  2. Submit questions via the API.
  3. Receive answers through your configured notification channel.
```

**Key Features:**
- 帮助页路由：`/help` → 静态 HTML，`/` → 后端服务
- 404 自动跳转：用户访问不存在的路径时自动重定向到帮助页
- ⚠️ `public_path` 必须包含 `/help`，否则 injects 无法访问帮助页
- 条件模板：`base_url` 未配置时自动使用 `{{.S.AppDomain}}` 拼接
- SQLite 数据持久化到 `/lzcapp/var/data`

---

## Key Patterns from Real Applications

### 1. **Image Sources**
```yaml
# Official images
image: nginx:latest

# Private registry (common in LazyCat)
image: registry.lazycat.cloud/user/image:tag

# Third-party registries
image: docker.1ms.run/namespace/image:tag
```

### 2. **Routing Methods**
```yaml
# Method 1: Routes (HTTP/HTTPS)
routes:
  - /=http://service:80
  - /api/=http://service:8080

# Method 2: Upstreams (Advanced HTTP)
upstreams:
  - location: /
    backend: http://service:80/
    disable_backend_ssl_verify: true

# Method 3: Ingress (TCP/UDP)
ingress:
  - protocol: tcp
    port: 22
    service: gitlab
```

### 3. **Storage Paths**
```yaml
binds:
  - /lzcapp/var/data:/app/data      # Permanent data
  - /lzcapp/cache/temp:/tmp         # Cache/temporary
  - /lzcapp/pkg/content:/app        # Read-only package files
```

### 4. **Health Checks**
```yaml
health_check:
  test:
    - CMD-SHELL
    - curl -f http://localhost:80/health
  start_period: 60s
  timeout: 10s
  interval: 30s
```

### 5. **Template Variables**
```yaml
environment:
  - DOMAIN=${LAZYCAT_APP_DOMAIN}           # App domain
  - BOX_DOMAIN=${LAZYCAT_BOX_DOMAIN}       # Box domain
  - USER_VAR={{.U.custom_setting}}         # User config
```

### 6. **Conditional Services**
```yaml
{{ if .U.enable_feature }}
services:
  extra-service:
    image: ...
{{ end }}
```

### 7. **Resource Management**
```yaml
services:
  app:
    cpu: 1000           # CPU shares (1000 = 1 core equivalent)
    mem_limit: 512M     # Memory limit
    cpu_shares: 512     # Lower priority
```

### 8. **Network Modes**
```yaml
# Default (isolated network)
services:
  app:
    image: ...

# Host network (direct access)
services:
  app:
    network_mode: host
    # Note: Can't use port mappings with host mode
```

### 9. **Multi-language Support**
```yaml
locales:
  zh:
    name: "应用名称"
    description: "应用描述"
  en:
    name: "App Name"
    description: "App Description"
```

### 10. **Background Tasks**
```yaml
application:
  background_task: true  # Prevents auto-sleep
```

### 11. **Injects (Response Phase - 404 Redirect)**
```yaml
application:
  injects:
    - id: redirect-404-to-help
      on: response
      auth_required: false
      when:
        - "/*"
      do: |
        if (ctx.status === 404) {
          ctx.response.send(302, "", { location: "/help" });
          return;
        }
```

### 12. **Static Help Page**
```yaml
application:
  upstreams:
    - location: /help
      backend: file:///lzcapp/pkg/content/web/index.html
    - location: /
      backend: http://app:8080/
  public_path:
    - /
    - /help  # ⚠️ 必须同时声明，否则 injects 无法访问
```

## Conversion Checklist

When converting from Docker to LazyCat:

- [ ] **Services**: Map each container to `services.*`
- [ ] **Images**: Use official or registry images
- [ ] **Ports**: HTTP → `routes`, TCP/UDP → `ingress`
- [ ] **Volumes**: Convert to `/lzcapp/var` or `/lzcapp/cache`
- [ ] **Environment**: Direct mapping
- [ ] **Dependencies**: `depends_on` between services
- [ ] **Health Checks**: Add if needed
- [ ] **Resources**: Add `cpu` and `mem_limit`
- [ ] **Network**: Check if `network_mode: host` needed
- [ ] **Routes/Upstreams**: Configure HTTP routing
- [ ] **Locales**: Add multi-language support
- [ ] **Icon**: Create 512x512 PNG icon
- [ ] **Build**: Create `lzc-build.yml`

## Common Issues & Solutions

### Issue: "Port already in use"
**Solution**: Use `routes` or `ingress` instead of direct port mapping

### Issue: "Data lost on restart"
**Solution**: Use `/lzcapp/var` or `/lzcapp/cache` for volumes

### Issue: "Can't access other services"
**Solution**: Use service names (e.g., `db:5432`) not `localhost`

### Issue: "Need host network access"
**Solution**: Use `network_mode: host` (carefully!)

### Issue: "Need custom domain"
**Solution**: Use `${LAZYCAT_APP_DOMAIN}` or user config variables

## Build & Deploy Commands

```bash
# Build the package
lzc-cli project build -o release.lpk

# Install to LazyCat
lzc-cli app install release.lpk

# Or upload to web interface
# 1. Go to LazyCat Web UI
# 2. Applications → Install Application
# 3. Upload release.lpk
```

## References

- **Official Docs**: https://developer.lazycat.cloud
- **App Examples**: https://gitee.com/lazycatcloud/appdb
- **Community Tools**: `docker2lzc` npm package