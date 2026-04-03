# LazyCat CLI Commands Reference

## Environment Setup

### Install lzc-cli (v2.0.0+ for LPK v2)

```bash
# Install v2 (recommended for LPK v2)
npm install -g @lazycatcloud/lzc-cli@2.0.0

# Or install latest
npm install -g @lazycatcloud/lzc-cli

# Verify version
lzc-cli --version
```

**Note:** LPK v2 format requires lzc-cli v2.0.0+.

### Prepare SSH Key

```bash
# Linux/macOS/Git Bash
[ -f ~/.ssh/id_ed25519.pub ] || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
```

### Select Target Microservice

```bash
lzc-cli box list
lzc-cli box switch <boxname>
lzc-cli box default
```

### Upload Public Key (hclient mode only)

```bash
lzc-cli box add-public-key
# Opens browser for authorization
```

### Add by SSH (alternative mode)

```bash
lzc-cli box add-by-ssh <loginUser> <address>
```

---

## Project Commands

### Create Project from Template

```bash
# Create from template
lzc-cli project create <project-name> -t <template>

# Available templates:
# - hello-vue        : Vue.js frontend
# - todolist-golang  : Go backend
# - springboot       : Java Spring Boot
# - python           : Python backend
# - node             : Node.js backend
```

### Deploy Project

```bash
# Deploy using dev config (lzc-build.dev.yml if exists)
lzc-cli project deploy

# Deploy using release config
lzc-cli project deploy --release
```

### Project Information

```bash
# View project info
lzc-cli project info

# View release config info
lzc-cli project info --release
```

### Start/Stop Project

```bash
# Start project
lzc-cli project start

# Stop project
lzc-cli project stop
```

### Execute Commands in Container

```bash
# Enter container shell
lzc-cli project exec /bin/sh

# Run command
lzc-cli project exec -- ls -la /app

# Enter specific service
lzc-cli project exec -s <service-name> /bin/sh
```

### Copy Files

```bash
# Copy file to container
lzc-cli project cp ./local-file.txt /app/remote-file.txt

# Copy file from container
lzc-cli project cp /app/remote-file.txt ./local-file.txt
```

### Sync Code

```bash
# One-time sync
lzc-cli project sync

# Watch mode - continuous sync
lzc-cli project sync --watch
```

### View Logs

```bash
# Follow logs
lzc-cli project log -f

# View specific service logs
lzc-cli project log -s <service-name> -f

# View last N lines
lzc-cli project log --tail 100
```

### Build Release Package

```bash
# Build LPK v2 package (default with lzc-cli v2.0.0+)
lzc-cli project release -o release.lpk

# Or use build command
lzc-cli project build -o release.lpk
```

**LPK v2 Format:**
- Tar-based (not zip)
- Requires `package.yml`
- Supports embedded images via `images/`

---

## LPK Package Commands

### Inspect LPK

```bash
# View package info
lzc-cli lpk info release.lpk

# Output includes:
# - format (tar for LPK v2, zip for LPK v1)
# - package
# - version
# - content files
```

**LPK v2 Output Example:**
```
format: tar
package: cloud.lazycat.app.myapp
version: 1.0.0
files:
  - manifest.yml
  - package.yml
  - content.tar.gz
```

### Install LPK

```bash
# Install package
lzc-cli lpk install release.lpk
```

---

## App Store Commands

### Login

```bash
lzc-cli appstore login
```

### Copy Image to Registry

```bash
# Copy image to LazyCat registry
lzc-cli appstore copy-image <image-name>:<tag>

# Example output:
# uploaded: registry.lazycat.cloud/czyt/engigu/baihu:45666f85198d186d
```

### Publish to App Store

```bash
# First-time publish (creates new app)
lzc-cli appstore publish release.lpk

# Update existing app
lzc-cli appstore publish release.lpk
```

### View My Images

```bash
lzc-cli appstore my-images
```

---

## Docker Commands

### View Container Logs

```bash
# Follow container logs
lzc-cli docker logs -f <container-name>
```

### Execute in Container

```bash
lzc-cli docker exec <container-name> <command>
```

---

## Quick Reference Table

| Task | Command |
|------|---------|
| Create project | `lzc-cli project create <name> -t <template>` |
| Deploy (dev) | `lzc-cli project deploy` |
| Deploy (release) | `lzc-cli project deploy --release` |
| View info | `lzc-cli project info` |
| Enter container | `lzc-cli project exec /bin/sh` |
| Sync code | `lzc-cli project sync --watch` |
| View logs | `lzc-cli project log -f` |
| Build release | `lzc-cli project release -o app.lpk` |
| Install LPK | `lzc-cli lpk install app.lpk` |
| Copy image | `lzc-cli appstore copy-image <image>` |
| Publish | `lzc-cli appstore publish app.lpk` |

---

## Common Workflows

### New Project Setup

```bash
# 1. Create project
lzc-cli project create myapp -t hello-vue
cd myapp

# 2. Deploy to target
lzc-cli project deploy

# 3. View info
lzc-cli project info

# 4. Open app and start dev server
npm run dev
```

### Backend Development

```bash
# 1. Deploy
lzc-cli project deploy

# 2. Start sync
lzc-cli project sync --watch

# 3. Enter container
lzc-cli project exec /bin/sh

# 4. Start backend manually
/app/run.sh
```

### Release and Publish

```bash
# 1. Build release package
lzc-cli project release -o myapp-1.0.0.lpk

# 2. Verify package
lzc-cli lpk info myapp-1.0.0.lpk

# 3. Copy image to registry
lzc-cli appstore copy-image myapp:latest

# 4. Update manifest with new image
# (Edit lzc-manifest.yml with registry.lazycat.cloud/... image)

# 5. Rebuild
lzc-cli project release -o myapp-1.0.0.lpk

# 6. Publish
lzc-cli appstore login
lzc-cli appstore publish myapp-1.0.0.lpk
```