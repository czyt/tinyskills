# PKGBUILD 模板语法与结构

## 基本结构

**⚠️ checksum 使用 'SKIP'，workflow 通过 `updpkgsums: true` 自动计算**

```bash
# Maintainer: {name} <{email}>
pkgname={pkgname}
pkgver={version}
pkgrel=1
pkgdesc="{description}"
arch=('x86_64')
url="{homepage}"
license=('{license}')
depends=({dependencies})
provides=('{provides}')
conflicts=('{conflicts}')
source=("{url}/releases/download/v${pkgver}/{file}")
sha256sums=('SKIP')  # ✅ workflow 自动计算

package() {
    install -Dm755 {binary} "${pkgdir}/usr/bin/{name}"
}
```

## 必需字段

| 字段 | 说明 | 示例 |
|------|------|------|
| `pkgname` | 包名 | `myapp-bin` |
| `pkgver` | 版本号 | `1.0.0` |
| `pkgrel` | 发布号 | `1` |
| `pkgdesc` | 描述 | `"A great application"` |
| `arch` | 架构 | `('x86_64')` 或 `('x86_64' 'aarch64')` |
| `url` | 主页 | `"https://github.com/user/repo"` |
| `license` | 许可证 | `('MIT')` `('GPL3')` |

## 可选字段

| 字段 | 说明 | 示例 |
|------|------|------|
| `depends` | 运行时依赖 | `('gtk3' 'libnotify')` |
| `makedepends` | 构建依赖 | `('go' 'rust')` |
| `optdepends` | 可选依赖 | `('libappindicator-gtk3: tray icon')` |
| `provides` | 提供功能 | `('myapp')` |
| `conflicts` | 冲突包 | `('myapp' 'myapp-git')` |
| `replaces` | 替换包 | `('oldapp')` |
| `install` | 安装脚本 | `'{pkgname}.install'` |

## 架构支持

### 单架构

```bash
arch=('x86_64')
source_x86_64=("${url}/releases/download/v${pkgver}/${file}-x64.tar.gz")
sha256sums_x86_64=('SKIP')
```

### 多架构

**⚠️ 多架构源文件必须使用不同的本地文件名**。`updpkgsums` 统一处理所有架构的源文件，若本地文件名相同则后下载的覆盖先下载的，checksum 将与实际文件不匹配。使用 `"local-name::URL"` 语法为每个架构指定不同文件名，并在 `package()` 中通过 `case $CARCH` 选择。

```bash
arch=('x86_64' 'aarch64')

# ✅ 每个架构用不同的本地文件名
source_x86_64=("${pkgname}-amd64::${url}/releases/download/v${pkgver}/${file}-x86_64.tar.gz")
source_aarch64=("${pkgname}-arm64::${url}/releases/download/v${pkgver}/${file}-aarch64.tar.gz")

sha256sums_x86_64=('SKIP')
sha256sums_aarch64=('SKIP')

package() {
    case "$CARCH" in
        x86_64)  _src="${pkgname}-amd64" ;;
        aarch64) _src="${pkgname}-arm64" ;;
    esac
    install -Dm755 "${srcdir}/${_src}" "${pkgdir}/usr/bin/${pkgname}"
}
```

**纯二进制（无压缩包）的多架构写法**：

```bash
source_x86_64=("${pkgname}-amd64::${url}/releases/download/v${pkgver}/${binary}-linux-amd64")
source_aarch64=("${pkgname}-arm64::${url}/releases/download/v${pkgver}/${binary}-linux-arm64")

sha256sums_x86_64=('SKIP')
sha256sums_aarch64=('SKIP')

package() {
    case "$CARCH" in
        x86_64)  _src="${pkgname}-amd64" ;;
        aarch64) _src="${pkgname}-arm64" ;;
    esac
    install -Dm755 "${srcdir}/${_src}" "${pkgdir}/usr/bin/${pkgname}"
}
```

## source 格式

### 直接下载

```bash
source=("${url}/releases/download/v${pkgver}/${file}")
sha256sums=('SKIP')
```

### 重命名文件

```bash
source=("${file}.tar.gz::${url}/releases/download/v${pkgver}/${file}")
sha256sums=('SKIP')
```

### 多文件

```bash
source=(
    "${url}/releases/download/v${pkgver}/${binary}"
    "${url}/releases/download/v${pkgver}/${config}"
)
sha256sums=('SKIP' 'SKIP')
```

## package() 函数

### 二进制安装

```bash
package() {
    install -Dm755 ${binary} "${pkgdir}/usr/bin/${pkgname}"
}
```

### deb 包解压

```bash
package() {
    ar p "${srcdir}/${source}" data.tar.gz | tar xz -C "${pkgdir}"
    chmod -R u=rwX,go=rX "${pkgdir}"
}
```

### 应用目录安装

```bash
package() {
    # 复制应用目录
    install -dm755 "${pkgdir}/opt"
    cp -r opt/MyApp "${pkgdir}/opt/"

    # 创建符号链接
    install -dm755 "${pkgdir}/usr/bin"
    ln -s /opt/MyApp/myapp "${pkgdir}/usr/bin/myapp"

    # 复制桌面文件
    install -Dm644 usr/share/applications/myapp.desktop \
        "${pkgdir}/usr/share/applications/myapp.desktop"

    # 复制图标
    for size in 16 32 48 64 128 256 512; do
        install -Dm644 "usr/share/icons/hicolor/${size}x${size}/apps/myapp.png" \
            "${pkgdir}/usr/share/icons/hicolor/${size}x${size}/apps/myapp.png"
    done
}
```

## install 文件 (.install)

### 基本结构

```bash
post_install() {
    echo "==> MyApp has been installed!"
    echo "==> Run 'myapp' to start the application"
}

post_upgrade() {
    echo "==> Upgraded to new version"
}

post_remove() {
    echo "==> MyApp has been removed"
}
```

### udev 规则安装

```bash
post_install() {
    echo "==> Installing udev rules..."
    udevadm control --reload-rules 2>/dev/null || true
    echo "==> You may need to replug your device"
}

post_remove() {
    udevadm control --reload-rules 2>/dev/null || true
}
```

## prepare() 函数

### deb 包准备

```bash
prepare() {
    cd "${srcdir}"
    bsdtar -xf "${source}"  # 解压 deb
    bsdtar -xf data.tar.* -C "${srcdir}"  # 解压 data
}
```

### 源码准备

```bash
prepare() {
    cd "${srcdir}/${pkgname}-${pkgver}"
    # 应用补丁
    patch -p1 -i "${srcdir}/fix-build.patch"
}
```

## build() 函数

### Go 项目

```bash
build() {
    cd "${srcdir}/${pkgname}-${pkgver}"
    go build -ldflags="-s -w" -o ${pkgname} .
}
```

### Rust 项目

```bash
build() {
    cd "${srcdir}/${pkgname}-${pkgver}"
    cargo build --release --locked
}
```

## check() 函数

```bash
check() {
    cd "${srcdir}/${pkgname}-${pkgver}"
    go test ./...
}
```

## 常见问题

### 1. checksum 使用

❌ 手动计算硬编码:
```bash
sha256sums=('abc123...')
```

✅ 使用 SKIP，workflow 自动计算:
```bash
sha256sums=('SKIP')  # workflow 通过 updpkgsums 更新
```

### 2. pkgname 命名

- 预编译包: `{name}-bin` (如 `myapp-bin`)
- Git 包: `{name}-git` (如 `myapp-git`)
- 源码包: `{name}` (如 `myapp`)

### 3. 许可证格式

```bash
license=('MIT')
license=('GPL3')
license=('Apache')
license=('custom:LICENSE')  # 自定义许可证
```

### 4. 依赖格式

```bash
depends=('gtk3' 'libnotify' 'nss')
optdepends=(
    'libappindicator-gtk3: system tray icon'
    'pulseaudio: audio support'
)
```

## 本地验证命令

```bash
# 验证 PKGBUILD
namcap PKGBUILD

# 构建测试
makepkg -sf

# 安装测试
sudo pacman -U {pkgname}-{version}-1-x86_64.pkg.tar.zst
```

## 参考链接

- [PKGBUILD 官方文档](https://wiki.archlinux.org/title/PKGBUILD)
- [Arch Packaging Standards](https://wiki.archlinux.org/title/Arch_package_guidelines)
- [namcap 文档](https://wiki.archlinux.org/title/Namcap)