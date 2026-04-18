# 真实项目示例

## AUR PKGBUILD 实例

### 实例 1: deb 包转换

来源: aur/cc-switch-bin/PKGBUILD

```bash
# Maintainer: czyt <czytcn@gmail.com>
pkgname=cc-switch-bin
pkgver=3.13.0
pkgrel=1
pkgdesc="A cross-platform desktop All-in-One assistant tool for Claude Code, Codex & Gemini CLI."
arch=('x86_64' 'aarch64')
url="https://github.com/farion1231/cc-switch"
license=('mit')
depends=('libayatana-appindicator' 'webkit2gtk-4.1' 'gtk3')
source_x86_64=("CC-Switch-v${pkgver}-Linux-x86_64.deb::https://github.com/farion1231/cc-switch/releases/download/v${pkgver}/CC-Switch-v${pkgver}-Linux-x86_64.deb")
source_aarch64=("CC-Switch-v${pkgver}-Linux-arm64.deb::https://github.com/farion1231/cc-switch/releases/download/v${pkgver}/CC-Switch-v${pkgver}-Linux-arm64.deb")
md5sums_x86_64=('SKIP')
md5sums_aarch64=('SKIP')

package() {
    local _debfile
    if [[ "$CARCH" == "x86_64" ]]; then
        _debfile="CC-Switch-v${pkgver}-Linux-x86_64.deb"
    else
        _debfile="CC-Switch-v${pkgver}-Linux-arm64.deb"
    fi

    # Extract the deb package
    ar p "${srcdir}/${_debfile}" data.tar.gz | tar xz -C "${pkgdir}"

    # Fix permissions
    chmod -R u=rwX,go=rX "${pkgdir}"
}
```

**特点**:
- 多架构支持 (x86_64 + aarch64)
- 使用 `ar` 解压 deb 包
- 使用 `md5sums` (有些项目用 md5 而非 sha256)
- 架构判断 `$CARCH`

### 实例 2: 二进制包 + install 文件

来源: aur/autocli-bin/PKGBUILD

```bash
# Maintainer: czyt <czytcn@gmail.com>
pkgname=autocli-bin
pkgver=0.3.7
pkgrel=1
pkgdesc="Blazing fast, memory-safe CLI tool for fetching information from websites"
arch=('x86_64' 'aarch64')
url="https://github.com/nashsu/AutoCLI"
license=('MIT')
provides=('autocli')
conflicts=('autocli')
install=autocli-bin.install  # ✅ 使用 install 文件
source_x86_64=("autocli-x86_64-${pkgver}.tar.gz::https://github.com/nashsu/AutoCLI/releases/download/v${pkgver}/autocli-x86_64-unknown-linux-musl.tar.gz")
source_aarch64=("autocli-aarch64-${pkgver}.tar.gz::https://github.com/nashsu/AutoCLI/releases/download/v${pkgver}/autocli-aarch64-unknown-linux-musl.tar.gz")
sha256sums_x86_64=('SKIP')
sha256sums_aarch64=('SKIP')

package() {
    install -Dm755 autocli "${pkgdir}/usr/bin/autocli"
}
```

**特点**:
- tar.gz 格式下载
- 包含 `.install` 文件
- 使用 `provides` 和 `conflicts`

### 实例 3: 应用目录安装 + udev 规则

来源: aur/blink1control2-bin/PKGBUILD

```bash
# Maintainer: czyt <czytcn@gmail.com>
pkgname=blink1control2-bin
pkgver=2.2.9
pkgrel=1
pkgdesc="Blink1Control GUI to control blink(1) USB RGB LED devices"
arch=('x86_64')
url="https://github.com/todbot/Blink1Control2"
license=('custom')
depends=('gtk3' 'libnotify' 'nss' 'libxss' 'libxtst' 'xdg-utils' 'at-spi2-core' 'util-linux' 'libsecret')
optdepends=('libappindicator-gtk3: system tray icon support')
provides=('blink1control2')
conflicts=('blink1control2')
source_x86_64=("https://github.com/todbot/Blink1Control2/releases/download/v${pkgver}/Blink1Control2-${pkgver}-linux-amd64.deb")
sha256sums_x86_64=('382d2a6a67a02c9d464b09fcdc46c0668ad930f262b94007783d58cde78a1bba')

prepare() {
    cd "${srcdir}"
    bsdtar -xf "Blink1Control2-${pkgver}-linux-amd64.deb"
    bsdtar -xf data.tar.* -C "${srcdir}"
}

package() {
    cd "${srcdir}"

    # Copy the application files
    install -dm755 "${pkgdir}/opt"
    cp -r opt/Blink1Control2 "${pkgdir}/opt/"

    # Set proper permissions for executables
    chmod 755 "${pkgdir}/opt/Blink1Control2/blink1control2"
    chmod 755 "${pkgdir}/opt/Blink1Control2/chrome-sandbox"

    # Copy desktop file
    install -Dm644 usr/share/applications/blink1control2.desktop \
        "${pkgdir}/usr/share/applications/blink1control2.desktop"

    # Copy icon files
    for size in 16 32 48 64 128 256 512; do
        install -Dm644 "usr/share/icons/hicolor/${size}x${size}/apps/blink1control2.png" \
            "${pkgdir}/usr/share/icons/hicolor/${size}x${size}/apps/blink1control2.png"
    done

    # Create symlink in /usr/bin
    install -dm755 "${pkgdir}/usr/bin"
    ln -s /opt/Blink1Control2/blink1control2 "${pkgdir}/usr/bin/blink1control2"

    # Install udev rules for blink(1) devices
    install -Dm644 /dev/stdin "${pkgdir}/usr/lib/udev/rules.d/51-blink1.rules" << 'EOF'
# Rule for blink(1) USB devices
SUBSYSTEM=="usb", ATTRS{idVendor}=="27b8", ATTRS{idProduct}=="01ed", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="27b8", ATTRS{idProduct}=="01ee", MODE="0666"
KERNEL=="hidraw*", ATTRS{idVendor}=="27b8", ATTRS{idProduct}=="01ed", MODE="0666"
KERNEL=="hidraw*", ATTRS{idVendor}=="27b8", ATTRS{idProduct}=="01ee", MODE="0666"
EOF
}

post_install() {
    echo "==> Reloading udev rules..."
    udevadm control --reload-rules 2>/dev/null || true
    echo "==> You may need to replug your blink(1) device or run:"
    echo "    sudo udevadm trigger"
}

post_upgrade() {
    post_install
}

post_remove() {
    echo "==> Reloading udev rules..."
    udevadm control --reload-rules 2>/dev/null || true
}
```

**特点**:
- 使用 `prepare()` 函数解压
- 安装到 `/opt` 目录
- 创建符号链接
- 安装桌面文件和图标
- 安装 udev 规则
- 包含 `post_install/post_upgrade/post_remove` 钩子

---

## GitHub Actions Workflow 实例

### 实例 1: 完整 AUR 自动更新流程

来源: aur/.github/workflows/update-blink1control2-bin.yml

```yaml
name: Update Blink1Control2-bin Version

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
            VERSION=$(curl -s https://api.github.com/repos/todbot/Blink1Control2/releases/latest | jq -r '.tag_name' | sed 's/^v//')
            echo "version=$VERSION" >> $GITHUB_OUTPUT
          fi

      - name: Get current version
        id: current_version
        run: |
          CURRENT=$(grep '^pkgver=' blink1control2-bin/PKGBUILD | cut -d'=' -f2)
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
              echo "Version ${{ steps.get_version.outputs.version }} is already up to date"
            fi
          else
            echo "needs_update=true" >> $GITHUB_OUTPUT
            echo "bump_rel=false" >> $GITHUB_OUTPUT
            echo "Updating from ${{ steps.current_version.outputs.current }} to ${{ steps.get_version.outputs.version }}"
          fi

      - name: Update PKGBUILD version
        if: steps.compare.outputs.needs_update == 'true'
        run: |
          cd blink1control2-bin
          if [ "${{ steps.compare.outputs.bump_rel }}" = "true" ]; then
            # Bump pkgrel for same version fix
            CURRENT_REL=$(grep '^pkgrel=' PKGBUILD | cut -d'=' -f2)
            NEW_REL=$((CURRENT_REL + 1))
            sed -i "s/^pkgrel=.*/pkgrel=$NEW_REL/" PKGBUILD
            echo "Bumped pkgrel from $CURRENT_REL to $NEW_REL"
          else
            # New version - update version and reset pkgrel to 1
            sed -i "s/^pkgver=.*/pkgver=${{ steps.get_version.outputs.version }}/" PKGBUILD
            sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
          fi

      - name: Commit changes
        if: steps.compare.outputs.needs_update == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add blink1control2-bin/PKGBUILD
          if [ "${{ steps.compare.outputs.bump_rel }}" = "true" ]; then
            git commit -m "Bump pkgrel for blink1control2-bin ${{ steps.get_version.outputs.version }}"
          else
            git commit -m "Update blink1control2-bin to version ${{ steps.get_version.outputs.version }}"
          fi
          git push

      - name: Publish to AUR
        if: steps.compare.outputs.needs_update == 'true'
        uses: KSXGitHub/github-actions-deploy-aur@v4.1.3
        with:
          pkgname: blink1control2-bin
          pkgbuild: ./blink1control2-bin/PKGBUILD
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
- `updpkgsums: true` 自动计算 checksum
- `post_process` 清理工作目录
- commit message 使用条件格式

---

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

**作用**: 清理 AUR 发布目录，只保留必要文件

---

## Workflow 最佳实践总结

### 1. 版本检测

```bash
# 从 GitHub API 获取
VERSION=$(curl -s https://api.github.com/repos/user/repo/releases/latest | jq -r '.tag_name' | sed 's/^v//')
```

### 2. pkgrel 管理

```bash
# 新版本: pkgver 更新, pkgrel 重置为 1
sed -i "s/^pkgver=.*/pkgver=$NEW_VERSION/" PKGBUILD
sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD

# 同版本修复: 只 bump pkgrel
CURRENT_REL=$(grep '^pkgrel=' PKGBUILD | cut -d'=' -f2)
NEW_REL=$((CURRENT_REL + 1))
sed -i "s/^pkgrel=.*/pkgrel=$NEW_REL/" PKGBUILD
```

### 3. 条件 commit message

```yaml
commit_message: ${{ steps.compare.outputs.bump_rel == 'true' && format('Bump pkgrel for version {0}', steps.get_version.outputs.version) || format('Update to version {0}', steps.get_version.outputs.version) }}
```

---

## 参考链接

- [AUR Wiki](https://wiki.archlinux.org/title/AUR)
- [PKGBUILD 文档](https://wiki.archlinux.org/title/PKGBUILD)
- [KSXGitHub/github-actions-deploy-aur](https://github.com/KSXGitHub/github-actions-deploy-aur)