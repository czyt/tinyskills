# GitHub Actions Workflow 模板

## AUR 自动更新 + 发布 Workflow

### 基本模板

```yaml
name: Update {pkgname} Version

on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version number. Leave empty to auto-detect."
        required: false
        type: string
      force:
        description: "Force update (bump pkgrel)"
        required: false
        default: false
        type: boolean
  schedule:
    - cron: "0 */12 * * *"

jobs:
  update-pkgbuild:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Get latest version
        id: get_version
        run: |
          if [ -n "${{ inputs.version }}" ]; then
            echo "version=${{ inputs.version }}" >> $GITHUB_OUTPUT
          else
            VERSION=$(curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r '.tag_name' | sed 's/^v//')
            echo "version=$VERSION" >> $GITHUB_OUTPUT
          fi

      - name: Get current version
        id: current_version
        run: |
          CURRENT=$(grep '^pkgver=' {pkgname}/PKGBUILD | cut -d'=' -f2)
          echo "current=$CURRENT" >> $GITHUB_OUTPUT

      - name: Compare versions
        id: compare
        run: |
          if [ "${{ steps.get_version.outputs.version }}" = "${{ steps.current_version.outputs.current }}" ]; then
            if [ "${{ inputs.force }}" = "true" ]; then
              echo "needs_update=true" >> $GITHUB_OUTPUT
              echo "bump_rel=true" >> $GITHUB_OUTPUT
            else
              echo "needs_update=false" >> $GITHUB_OUTPUT
            fi
          else
            echo "needs_update=true" >> $GITHUB_OUTPUT
            echo "bump_rel=false" >> $GITHUB_OUTPUT
          fi

      - name: Update PKGBUILD
        if: steps.compare.outputs.needs_update == 'true'
        run: |
          cd {pkgname}
          if [ "${{ steps.compare.outputs.bump_rel }}" = "true" ]; then
            # Bump pkgrel
            CURRENT_REL=$(grep '^pkgrel=' PKGBUILD | cut -d'=' -f2)
            NEW_REL=$((CURRENT_REL + 1))
            sed -i "s/^pkgrel=.*/pkgrel=$NEW_REL/" PKGBUILD
          else
            # Update version
            sed -i "s/^pkgver=.*/pkgver=${{ steps.get_version.outputs.version }}/" PKGBUILD
            sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
          fi

      - name: Commit changes
        if: steps.compare.outputs.needs_update == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add {pkgname}/PKGBUILD
          git commit -m "Update {pkgname} to version ${{ steps.get_version.outputs.version }}"
          git push

      - name: Publish to AUR
        if: steps.compare.outputs.needs_update == 'true'
        uses: KSXGitHub/github-actions-deploy-aur@v4.1.3
        with:
          pkgname: {pkgname}
          pkgbuild: ./{pkgname}/PKGBUILD
          updpkgsums: true  # ✅ 自动计算 checksum
          commit_username: ${{ secrets.AUR_USERNAME }}
          commit_email: ${{ secrets.AUR_EMAIL }}
          ssh_private_key: ${{ secrets.AUR_SSH_PRIVATE_KEY }}
          commit_message: "Update to version ${{ steps.get_version.outputs.version }}"
          ssh_keyscan_types: rsa,ecdsa,ed25519
```

## KSXGitHub/github-actions-deploy-aur 参数

| 参数 | 说明 | 必需 |
|------|------|------|
| `pkgname` | AUR 包名 | ✅ |
| `pkgbuild` | PKGBUILD 文件路径 | ✅ |
| `updpkgsums` | 自动计算 checksum | 推荐 |
| `assets` | 附加文件 (.install, .patch) | 可选 |
| `commit_username` | AUR 用户名 | ✅ |
| `commit_email` | AUR 邮箱 | ✅ |
| `ssh_private_key` | AUR SSH 私钥 | ✅ |
| `commit_message` | 提交消息 | ✅ |
| `post_process` | 后处理脚本 | 可选 |
| `ssh_keyscan_types` | SSH 密钥类型 | 推荐 |

## 真实实例

### 实例 1: 二进制包自动更新

来源: aur/.github/workflows/update-autocli-bin.yml

```yaml
name: Update autocli-bin Version

on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version number. Leave empty to auto-detect."
        required: false
        type: string
      force:
        description: "Force update (bump pkgrel)"
        required: false
        default: false
        type: boolean
  schedule:
    - cron: "0 */12 * * *"

jobs:
  update-pkgbuild:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Get latest version
        id: get_version
        run: |
          if [ -n "${{ github.event.inputs.version }}" ]; then
            echo "version=${{ github.event.inputs.version }}" >> $GITHUB_OUTPUT
          else
            VERSION=$(curl -s https://api.github.com/repos/nashsu/AutoCLI/releases/latest | jq -r '.tag_name' | sed 's/^v//')
            echo "version=$VERSION" >> $GITHUB_OUTPUT
          fi

      - name: Get current version
        id: current_version
        run: |
          CURRENT=$(grep '^pkgver=' autocli-bin/PKGBUILD | cut -d'=' -f2)
          echo "current=$CURRENT" >> $GITHUB_OUTPUT

      - name: Compare versions
        id: compare
        run: |
          if [ "${{ steps.get_version.outputs.version }}" = "${{ steps.current_version.outputs.current }}" ]; then
            if [ "${{ github.event.inputs.force }}" = "true" ]; then
              echo "needs_update=true" >> $GITHUB_OUTPUT
              echo "bump_rel=true" >> $GITHUB_OUTPUT
              echo "Forcing pkgrel bump for version ${{ steps.get_version.outputs.version }}"
            else
              echo "needs_update=false" >> $GITHUB_OUTPUT
              echo "Version is already up to date"
            fi
          else
            echo "needs_update=true" >> $GITHUB_OUTPUT
            echo "bump_rel=false" >> $GITHUB_OUTPUT
            echo "Updating from ${{ steps.current_version.outputs.current }} to ${{ steps.get_version.outputs.version }}"
          fi

      - name: Update PKGBUILD version
        if: steps.compare.outputs.needs_update == 'true'
        run: |
          cd autocli-bin
          if [ "${{ steps.compare.outputs.bump_rel }}" = "true" ]; then
            CURRENT_REL=$(grep '^pkgrel=' PKGBUILD | cut -d'=' -f2)
            NEW_REL=$((CURRENT_REL + 1))
            sed -i "s/^pkgrel=.*/pkgrel=$NEW_REL/" PKGBUILD
            echo "Bumped pkgrel from $CURRENT_REL to $NEW_REL"
          else
            sed -i "s/^pkgver=.*/pkgver=${{ steps.get_version.outputs.version }}/" PKGBUILD
            sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
          fi

      - name: Commit changes
        if: steps.compare.outputs.needs_update == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add autocli-bin/PKGBUILD
          if [ "${{ steps.compare.outputs.bump_rel }}" = "true" ]; then
            git commit -m "Bump pkgrel for autocli-bin ${{ steps.get_version.outputs.version }}"
          else
            git commit -m "Update autocli-bin to version ${{ steps.get_version.outputs.version }}"
          fi
          git push

      - name: Publish to AUR
        if: steps.compare.outputs.needs_update == 'true'
        uses: KSXGitHub/github-actions-deploy-aur@v4.1.3
        with:
          pkgname: autocli-bin
          pkgbuild: ./autocli-bin/PKGBUILD
          assets: ./autocli-bin/autocli-bin.install  # 包含 install 文件
          updpkgsums: true  # ✅ 自动计算 checksum
          post_process: bash /github/workspace/.github/scripts/prune-aur-workdir.sh .
          commit_username: ${{ secrets.AUR_USERNAME }}
          commit_email: ${{ secrets.AUR_EMAIL }}
          ssh_private_key: ${{ secrets.AUR_SSH_PRIVATE_KEY }}
          commit_message: ${{ steps.compare.outputs.bump_rel == 'true' && format('Bump pkgrel for version {0}', steps.get_version.outputs.version) || format('Update to version {0}', steps.get_version.outputs.version) }}
          ssh_keyscan_types: rsa,ecdsa,ed25519
```

**关键点**:
- `force` 参数支持同版本 bump pkgrel
- `assets` 包含 .install 文件
- `updpkgsums: true` 自动计算 checksum
- `post_process` 清理工作目录

### 实例 2: deb 包自动更新

来源: aur/.github/workflows/update-cc-switch-bin.yml

```yaml
- name: Update PKGBUILD version
  if: steps.compare.outputs.needs_update == 'true'
  run: |
    cd cc-switch-bin
    if [ "${{ steps.compare.outputs.bump_rel }}" = "true" ]; then
      CURRENT_REL=$(grep '^pkgrel=' PKGBUILD | cut -d'=' -f2)
      NEW_REL=$((CURRENT_REL + 1))
      sed -i "s/^pkgrel=.*/pkgrel=$NEW_REL/" PKGBUILD
    else
      sed -i "s/^pkgver=.*/pkgver=${{ steps.get_version.outputs.version }}/" PKGBUILD
      sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
    fi
```

### 实例 3: 多架构包

```yaml
- name: Update PKGBUILD
  run: |
    cd {pkgname}
    # 更新版本
    sed -i "s/^pkgver=.*/pkgver=${{ steps.get_version.outputs.version }}/" PKGBUILD
    sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD

    # 更新 source URL（如果有版本号在 URL 中）
    sed -i "s|v[0-9.]*-Linux|v${{ steps.get_version.outputs.version }}-Linux|g" PKGBUILD
```

## prune-aur-workdir.sh 脚本

来源: aur/.github/scripts/prune-aur-workdir.sh

```bash
#!/usr/bin/env bash

set -euo pipefail

workdir=${1:-.}

if [[ ! -d "${workdir}" ]]; then
  echo "workdir does not exist: ${workdir}" >&2
  exit 1
fi

shopt -s dotglob nullglob

for path in "${workdir}"/*; do
  name=$(basename -- "${path}")

  case "${name}" in
    .|..|.git|PKGBUILD|.SRCINFO|*.install|*.patch|*.conf|*.service|*.desktop)
      continue
      ;;
  esac

  rm -rf -- "${path}"
done
```

**作用**: 清理 AUR 发布目录，只保留必要文件:
- PKGBUILD
- .SRCINFO
- *.install
- *.patch
- *.conf
- *.service
- *.desktop

## Secrets 配置

### GitHub Secrets 设置

| Secret | 获取方式 |
|--------|----------|
| `AUR_USERNAME` | AUR 注册用户名 |
| `AUR_EMAIL` | AUR 注册邮箱 |
| `AUR_SSH_PRIVATE_KEY` | AUR SSH 私钥 |

### SSH 密钥生成

```bash
# 生成 SSH 密钥
ssh-keygen -f aur_key -t ed25519 -C "your@email.com"

# 上传公钥到 AUR
# 登录 https://aur.archlinux.org/account/
# 在 "SSH Public Key" 字段粘贴 aur_key.pub 内容

# 将私钥添加到 GitHub Secrets
# 复制 aur_key 完整内容（包括 BEGIN/END 行）
```

## 常用 sed 命令

```bash
# 更新 pkgver
sed -i "s/^pkgver=.*/pkgver=${NEW_VERSION}/" PKGBUILD

# 更新 pkgrel
sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD

# bump pkgrel
CURRENT_REL=$(grep '^pkgrel=' PKGBUILD | cut -d'=' -f2)
NEW_REL=$((CURRENT_REL + 1))
sed -i "s/^pkgrel=.*/pkgrel=$NEW_REL/" PKGBUILD

# 更新 source URL 中的版本
sed -i "s|v[0-9.]*-|v${NEW_VERSION}-|g" PKGBUILD
```

## 参考链接

- [KSXGitHub/github-actions-deploy-aur](https://github.com/KSXGitHub/github-actions-deploy-aur)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [AUR 提交指南](https://wiki.archlinux.org/title/AUR_submission_guidelines)

---

## ⚠️ GitHub Actions 版本检查

**在使用本模板之前，请检查以下 GitHub Actions 的最新版本**：

```bash
# 检查 actions/checkout 最新版本
curl -s https://api.github.com/repos/actions/checkout/releases/latest | jq -r '.tag_name'

# 检查 KSXGitHub/github-actions-deploy-aur 最新版本
curl -s https://api.github.com/repos/KSXGitHub/github-actions-deploy-aur/releases/latest | jq -r '.tag_name'

# 检查 actions/setup-go 最新版本
curl -s https://api.github.com/repos/actions/setup-go/releases/latest | jq -r '.tag_name'

# 检查 goreleaser/goreleaser-action 最新版本
curl -s https://api.github.com/repos/goreleaser/goreleaser-action/releases/latest | jq -r '.tag_name'
```

| Action | 当前模板版本 | 检查最新 |
|--------|-------------|---------|
| `actions/checkout` | v6 | [releases](https://github.com/actions/checkout/releases) |
| `KSXGitHub/github-actions-deploy-aur` | v4.1.3 | [releases](https://github.com/KSXGitHub/github-actions-deploy-aur/releases) |
| `actions/setup-go` | v6 | [releases](https://github.com/actions/setup-go/releases) |
| `goreleaser/goreleaser-action` | v7 | [releases](https://github.com/goreleaser/goreleaser-action/releases) |
| `softprops/action-gh-release` | v3 | [releases](https://github.com/softprops/action-gh-release/releases) |
| `actions/upload-artifact` | v7 | [releases](https://github.com/actions/upload-artifact/releases) |
| `actions/download-artifact` | v8 | [releases](https://github.com/actions/download-artifact/releases) |

**最佳实践**: 每次创建新 workflow 时，先检查上述 Actions 是否有新版本发布，使用最新版本可以获得更好的性能和安全性。