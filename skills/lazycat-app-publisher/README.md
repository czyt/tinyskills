# LazyCat App Publisher Skill

A Claude Code skill for converting Docker Compose files and Docker commands into LazyCat Cloud application configurations, including complete publish workflow automation.

## 🎯 What This Skill Does

This skill helps you:
1. **🔍 Automatic App Store Check**: Checks if the app already exists before conversion (NEW!)
2. **Convert Docker to LazyCat**: Docker Compose/Run → `lzc-manifest.yml`, `lzc-build.yml`, `lzc-deploy-params.yml`
3. **Setup Wizard Configuration**: Multi-language parameter definitions (English params + Chinese locales)
4. **Image Management**: `lzc-cli appstore copy-image` workflow
5. **Auto-Update Manifest**: Automatically updates manifest after image copy
6. **Complete Publish Workflow**: 4-stage process from build to publish
7. **Automation Scripts**: Full `build.sh` with interactive menu

## 📦 What Gets Generated

### 1. lzc-manifest.yml (Main Config)
```yaml
lzc-sdk-version: '0.1'
name: AppName
package: cloud.lazycat.app.appname
version: 1.0.0
application:
  subdomain: appname
  background_task: true  # For non-HTTP apps
services:
  web:
    image: registry.lazycat.cloud/...  # Must use LazyCat registry
    environment:
      - TOKEN={{.U.my_token}}  # User parameter (lowercase)
    binds:
      - /lzcapp/var/data:/data
    cpu_shares: 512
    mem_limit: 256M
    healthcheck:
      test: ["CMD", "pgrep", "app"]
locales:
  zh:
    name: "应用名称"
```

### 2. lzc-deploy-params.yml (Setup Wizard - CRITICAL)
```yaml
# ⚠️ KEY RULE: params.id uses lowercase English (recommended), English text, Chinese locales
params:
  - id: my_token              # 💡 Recommended: lowercase with underscores
    type: string
    name: "my token"           # English
    description: "API token"   # English
    optional: false

locales:
  zh:
    my_token:                  # Matches params.id (lowercase)
      name: "我的 Token"       # Chinese
      description: "API Token" # Chinese
```

**💡 Best Practice:** Use lowercase params.id (e.g., `my_token`) for better readability, even though uppercase (e.g., `MY_TOKEN`) is also valid.

### 3. lzc-build.yml
```yaml
pkgout: ./
icon: ./icon.png  # User-provided 512x512 PNG
```

**Note**: Icon must be provided by user as a 512x512 PNG file.

### 4. build.sh (Complete Automation)
```bash
#!/bin/bash
# Menu: 1-Build, 2-Copy Image, 3-Publish, 4-One-Click, 5-Info, 6-Exit
# Auto-updates manifest after image copy
# Supports first-time and update publishing
```

## 🔍 Automatic App Store Check (NEW!)

**This is an automatic feature that runs before every conversion!**

### How It Works

Whenever you request to convert or create an application, the skill **automatically**:
1. 🔍 Detects the application name from your docker-compose.yml or description
2. 🌐 Searches the LazyCat App Store API: `https://search.lazycat.cloud/api/v1/app?keyword={app_name}`
3. 📊 Analyzes results for exact matches and similar apps
4. 💬 Presents findings to you with detailed information
5. ❓ Asks if you want to continue creating the app

### What You See

**If an exact match is found:**
```
⚠️  应用商店检查结果

找到 1 个完全匹配的应用：
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Tailscale
   包名: cloud.lazycat.app.tailscale
   版本: 1.92.3
   作者: 虫子樱桃 (czyt)
   下载: 309 次
   评分: ⭐⭐⭐⭐ (4.0)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

建议：
1. ❌ 停止 - 直接安装现有应用
2. 🤝 贡献 - 联系作者改进
3. ✏️  继续 - 使用不同名称

是否继续创建？
```

**If no match is found:**
```
✅ 应用商店中未找到同名应用，可以继续创建
```

### Benefits

✅ **Prevents Duplicate Work**: Saves your time by identifying existing apps  
✅ **Encourages Collaboration**: Suggests contributing instead of duplicating  
✅ **Maintains Quality**: Prevents app store fragmentation  
✅ **Zero Configuration**: Works automatically, no setup needed  

### Example Usage

```
User: 帮我转换 Tailscale 的 docker-compose.yml

Skill: 🔍 正在检查懒猫应用商店...
       ⚠️  发现已存在 Tailscale 应用！
       [Shows app details]
       是否继续创建？

User: 不了，我直接用现有的

Skill: ✅ 好的，您可以直接在商店搜索安装
```

**Skip Check (Optional):**
If you're certain the app doesn't exist:
```
请转换这个 docker-compose.yml（跳过商店检查）:
[provide file]
```

## ⚙️ Skill Preferences

This skill supports configurable preferences to customize the generated manifest:

### Add / to public_path (default: enabled)

**Preference ID**: `add_root_to_public_path`

By default, the skill automatically adds `"/"` to the `application.public_path` array in generated manifests. This is useful for applications that:
- Serve static files
- Need root path public access
- Use file handlers for downloads

**With preference enabled (default)**:
```yaml
application:
  subdomain: myapp
  public_path:
    - /
  upstreams:
    - location: /
      backend: http://myapp:8080/
```

**With preference disabled**:
```yaml
application:
  subdomain: myapp
  upstreams:
    - location: /
      backend: http://myapp:8080/
```

### Manifest Multilingual Support (default: enabled)

**Preference ID**: `manifest_multilingual`

By default, the skill generates `locales` with both English and Chinese translations in manifest files.

**With preference enabled (default)**:
```yaml
locales:
  en:
    name: "My App"
    description: "Great application"
  zh:
    name: "我的应用"
    description: "很棒的应用程序"
```

### Simple App Optimization (default: enabled)

**Preference ID**: `simple_app_optimization`

Automatically detects simple applications and skips `lzc-deploy-params.yml` generation.

**Simple app characteristics**:
- Zero configuration required
- No sensitive environment variables
- No internal dependencies

**Result**: Simple apps like Taskpony generate only `lzc-manifest.yml` and `lzc-build.yml`.

### Auto Healthcheck & Resource Limits (default: enabled)

**Preference IDs**: `auto_healthcheck`, `auto_resource_limits`

Automatically adds health checks and reasonable resource limits to services.

### Minimal Documentation (default: enabled)

**Preference ID**: `minimal_docs`

Keeps application directory clean by generating only essential files.

**When enabled (default)**:
```
app-directory/
├── lzc-manifest.yml
├── lzc-build.yml
├── build.sh
└── README.md  # User-focused guide only
```

**When disabled**:
```
app-directory/
├── lzc-manifest.yml
├── lzc-build.yml
├── build.sh
├── README.md
├── QUICKSTART.md
├── SUMMARY.md
├── PREFERENCES.md
└── PREFERENCE-UPDATE-CONFIRM.md
```

**How to configure**: Access skill preferences through Claude Code settings.

## 🚀 Quick Usage Examples

### Example 1: Convert Docker Compose
```
Convert this docker-compose.yml to LazyCat app:
version: '3'
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html
```

### Example 2: Convert Docker Run
```
Convert this docker run command:
docker run -d -p 8080:80 -e APP_ENV=production nginx
```

### Example 3: Complex Multi-service
```
Convert this full-stack docker-compose.yml to LazyCat:
[provide docker-compose.yml with app, database, cache]
```

## 📚 Examples Included

The skill includes comprehensive examples:

1. **docker-compose-examples.md** - Common Docker Compose patterns
2. **docker-run-examples.md** - Docker run command conversions
3. **real-world-examples.md** - Actual LazyCat apps from the community

### Covered Scenarios
- ✅ Simple web servers (Nginx, Apache)
- ✅ Databases (PostgreSQL, MySQL, MongoDB, Redis)
- ✅ Full-stack apps (WordPress, Nextcloud, GitLab)
- ✅ Management tools (Portainer, Jenkins)
- ✅ File hosting (Nextcloud, Vaultwarden)
- ✅ Network tools (Cloudflared, Lucky)
- ✅ CI/CD tools (Jenkins, GitLab)

## 🔧 Key Conversion Rules

| Docker Feature | LazyCat Equivalent |
|----------------|-------------------|
| `ports: ["80:80"]` | HTTP: `upstreams: [{location: "/", backend: "http://service:80/"}]`<br>TCP/UDP: `ingress: [{port: 80}]` |
| `volumes: ["./data:/app"]` | `binds: ["/lzcapp/var/data:/app"]` |
| `environment: VAR=value` | `environment: ["VAR=value"]` |
| `command: [sh, -c, cmd]` | ⚠️ `command: "sh -c 'cmd'"` **(must be string, not array)** |
| `depends_on: ["db"]` | `depends_on: ["db"]` |
| `restart: always` | `restart: always` |
| `network_mode: host` | `network_mode: "host"` |

## 📂 Storage Path Mapping

**Important**: Always use these paths for persistent data:

- **`/lzcapp/var`** - Permanent storage (survives container restarts)
- **`/lzcapp/cache`** - Cache storage (survives container restarts)
- **`/lzcapp/pkg`** - Package content (read-only)
- **`/lzcapp/run`** - Runtime data (cleared on restart)

### Example Conversion
```yaml
# Docker
volumes:
  - ./data:/app/data
  - ./cache:/app/cache

# LazyCat
binds:
  - /lzcapp/var/data:/app/data
  - /lzcapp/cache:/app/cache
```

## 🌐 Routing Configuration

### HTTP/HTTPS Services
```yaml
application:
  routes:
    - /=http://appname.cloud.lazycat.app.appname.lzcapp:80
    - /api/=http://appname.cloud.lazycat.app.appname.lzcapp:8080
```

### TCP/UDP Services (SSH, Database, etc.)
```yaml
application:
  ingress:
    - protocol: tcp
      port: 22
      service: gitlab
      description: "SSH for Git operations"
```

## 🎨 Real-World Examples

### GitLab with SSH
```yaml
# Input: Docker Compose with ports 80, 443, 22
# Output:
application:
  routes:
    - /=http://gitlab...:80
  ingress:
    - protocol: tcp
      port: 22
      service: gitlab
```

### WordPress with Database
```yaml
# Input: Multi-service docker-compose
# Output:
services:
  wordpress:
    image: wordpress:latest
    depends_on:
      - db
    binds:
      - /lzcapp/var/wordpress:/var/www/html

  db:
    image: mysql:5.7
    binds:
      - /lzcapp/var/mysql:/var/lib/mysql
```

## 📋 Complete Publish Workflow (4-Stage)

### Stage 1: Initial Build
```bash
# Build with original image
lzc-cli project build -o app-1.0.0.lpk
```

### Stage 2: Image Copy to LazyCat Registry
```bash
# Copy image to official registry
lzc-cli appstore copy-image heizicao/yuque-sync:latest

# Output:
# lazycat-registry: registry.lazycat.cloud/czyt/heizicao/yuque-sync:HASH
```

### Stage 3: Auto-Update Manifest & Rebuild
```bash
# Script automatically updates manifest
# Then rebuild with new image
lzc-cli project build -o app-1.0.1.lpk
```

### Stage 4: Publish to App Store
```bash
# First-time: Creates new app
# Updates: Updates existing app
lzc-cli appstore publish app-1.0.1.lpk
```

### Complete Automation
```bash
# Use the build.sh script
./build.sh
# Select 4 - One-Click Publish
# Handles all 4 stages automatically
```

## 🔄 First-Time vs Update Publishing

| Aspect | First-Time | Update |
|--------|------------|--------|
| **Command** | `publish app-1.0.0.lpk` | `publish app-1.0.1.lpk` |
| **Result** | Creates new app | Updates existing app |
| **Version** | 1.0.0 | 1.0.1, 1.0.2, ... |
| **Review Time** | 1-3 days | 1-3 days |

**Key Difference**: Same command, different result based on app package name and version.

## ⚙️ Advanced Features

### Template Variables
```yaml
environment:
  - DOMAIN=${LAZYCAT_APP_DOMAIN}
  - USER_VAR={{.U.custom_setting}}
```

### Conditional Services
```yaml
{{ if .U.enable_backup }}
services:
  backup:
    image: backup-tool
{{ end }}
```

### Health Checks
```yaml
services:
  app:
    health_check:
      test:
        - CMD-SHELL
        - curl -f http://localhost:80/health
      start_period: 60s
```

### Multi-language Support
```yaml
locales:
  zh:
    name: "应用名称"
    description: "应用描述"
  en:
    name: "App Name"
    description: "App Description"
```

## 🚫 Limitations

### Not Supported
- Docker secrets
- Docker configs
- Build contexts
- Port ranges
- Custom health check commands (use defaults)

### Partial Support
- **Ports**: HTTP uses routes, TCP/UDP uses ingress
- **Networks**: Limited to default or host mode
- **Custom networks**: Not supported

## 📖 Official Documentation

### Primary Sources
- **Developer Portal**: https://developer.lazycat.cloud
- **Documentation Repo**: https://gitee.com/lazycatcloud/lzc-developer-doc
- **App Store**: https://gitee.com/lazycatcloud/appdb

### Key Documentation Pages
- Setup Wizard Spec: `/spec/deploy-params.html`
- App Publishing: `/docs/publish-app.html`
- lzc-cli Reference: `/docs/lzc-cli.html`
- Store Submission: `/docs/store-submission-guide.html`

### Real-World Example
- **Yuque Sync Project**: `/home/czyt/code/lazycat/yuque-sync-lzcapp`
- Complete 4-stage publish workflow with automation

## 🎯 Use Cases

- **Migration**: Move existing Docker apps to LazyCat
- **Prototyping**: Quickly create LazyCat apps from Docker configs
- **Learning**: Understand LazyCat app structure
- **Automation**: CI/CD pipelines for app publishing
- **Templates**: Reusable app configurations

## 📝 Quick Reference

See `QUICK_REFERENCE.md` for a condensed version of all key information.

## 🔍 Examples Directory

- `docker-compose-examples.md` - Common compose patterns
- `docker-run-examples.md` - Docker run conversions
- `real-world-examples.md` - Actual production apps

## 💡 Critical Rules & Tips

### 1. Setup Wizard Parameter Format (MOST IMPORTANT)
```yaml
# ❌ WRONG - Chinese in params
params:
  - id: yuque_token         # ⚠️ Lowercase recommended
    name: "语雀 Token"      # Wrong!
    description: "API说明"  # Wrong!

# ✅ CORRECT - Lowercase English IDs + English text, Chinese locales
params:
  - id: yuque_token         # 💡 Recommended: lowercase with underscores
    name: "yuque token"     # English
    description: "API Token for Yuque"  # English

locales:
  zh:
    yuque_token:            # Matches params.id
      name: "语雀 Token"    # Chinese
      description: "语雀 API Token说明"  # Chinese
```

**💡 Best Practice:** Use lowercase params.id (e.g., `yuque_token`) for better readability, even though uppercase (e.g., `YUQUE_TOKEN`) is also valid.

### 2. Image Must Be in LazyCat Registry
```yaml
# ❌ WRONG - Public image
services:
  web:
    image: heizicao/yuque-sync:latest

# ✅ CORRECT - LazyCat registry image
services:
  web:
    image: registry.lazycat.cloud/czyt/heizicao/yuque-sync:HASH
```

### 3. Manifest Auto-Update After Copy
```bash
# After lzc-cli appstore copy-image
# Script automatically: sed -i "s|image: .*|image: $new_image|" lzc-manifest.yml
# Then you MUST rebuild
```

### 4. Storage Paths
- **`/lzcapp/var`** - Permanent data (survives restarts)
- **`/lzcapp/cache`** - Cache data (survives restarts)

### 5. 4-Stage Publish Process
```
Stage 1: Initial Build → Stage 2: Image Copy → Stage 3: Rebuild → Stage 4: Publish
```

### Quick Commands
```bash
# Local testing
./build.sh → Select 5 (View Info)

# One-click publish
./build.sh → Select 4 (One-Click Publish)
```

---

**Skill Updated**: 2025-12-25
**Based on**: LazyCat Cloud official documentation and Yuque Sync real-world project