---
name: aur-github-publish
description: AUR GitHub 发布助手 - 自动更新 PKGBUILD 版本、发布到 GitHub 仓库并同步到 AUR。支持首次发布引导（版本差异触发策略）、三种场景：版本监控更新、编译发布一体化（GitHub Action）、GoReleaser集成（aurs/aur_sources）。支持手动版本输入、自动版本检测、pkgrel bump、多架构支持（x86_64/aarch64）、deb/rpm/tar.gz 包处理。包含四种包类型命名规则（-bin/-git/无后缀/-font）。触发词：首次发布 AUR、创建新 AUR 包、更新 AUR 包、发布到 AUR、创建 PKGBUILD、更新 Arch Linux 包、AUR 自动发布、GoReleaser AUR。
---

# AUR GitHub 发布助手

协助将软件版本更新到 AUR (Arch User Repository)，自动化版本检测、PKGBUILD 更新、GitHub 发布和 AUR 同步流程。

## Reference Documents

| Document | Content |
|----------|---------|
| [references/initial-publish-guide.md](references/initial-publish-guide.md) | ⭐ 首次发布引导（版本差异触发策略） |
| [references/pkgbuild-template.md](references/pkgbuild-template.md) | PKGBUILD 模板语法与结构 |
| [references/workflow-template.md](references/workflow-template.md) | GitHub Actions workflow 模板（含真实实例） |
| [references/aur-deploy-action.md](references/aur-deploy-action.md) | AUR 部署 action 配置 + 首次发布指南 |
| [references/package-types.md](references/package-types.md) | 不同包类型处理 (deb/rpm/tar.gz/AppImage) |
| [references/best-practices.md](references/best-practices.md) | 最佳实践与常见问题 |
| [references/real-world-examples.md](references/real-world-examples.md) | 真实项目示例（含 GitHub Action 实例） |
| [references/goreleaser-aur.md](references/goreleaser-aur.md) | GoReleaser AUR 集成（aurs/aur_sources） |

---

## 三种发布场景 ⚠️

选择正确的发布场景是配置的第一步：

| 场景 | 描述 | 适用情况 | 推荐配置 |
|------|------|---------|---------|
| **场景一：版本监控更新** | 定时检测上游版本，自动更新 AUR | 维护第三方项目的 AUR 包 | GitHub workflow + schedule |
| **场景二：编译发布一体化** | Tag 推送 → 编译 → Release → 推 AUR | 自己项目的发布流程 | GitHub workflow + publish-aur job |
| **场景三：GoReleaser 集成** | GoReleaser 自动构建 + 发布 AUR | Go/Rust 等项目 | `.goreleaser.yml` aurs/aur_sources |

### ⚠️ 关键检查点：选择场景

```
询问用户：
「请确认发布场景：
- 维护第三方项目 → 场景一（版本监控）
- 自己项目编译后直接推 AUR → 场景二（编译发布一体化）
- Go/Rust 项目使用 GoReleaser → 场景三（GoReleaser）

您属于哪种场景？」
```

---

## 仓库结构

### AUR GitHub 标准布局

```
aur-repo/
├── {pkgname}/
│   ├── PKGBUILD           # 包构建文件
│   ├── {pkgname}.install  # 安装钩子（可选）
│   └── .SRCINFO           # 源信息（自动生成）
├── .github/
│   ├── workflows/
│   │   ├── update-{pkgname}.yml
│   │   └── ...
│   └── scripts/
│       └── prune-aur-workdir.sh
└── README.md
```

---

## 类型分类与命名规则

### 四种类型自动判断

| 类型特征 | 命名后缀 | 构建方式 | 判断依据 |
|---------|---------|---------|---------|
| **Binary (-bin)** | `{name}-bin` | 直接安装预编译二进制 | 上游提供预编译二进制文件 |
| **VCS (-git)** | `{name}-git` | 从 Git 源码构建 | 用户需要最新开发版本 |
| **Source** | `{name}` | 从稳定源码版本构建 | 上游只提供源码，用户需要稳定版 |
| **Font** | `{name}-font` 或 `font-{name}` | 安装字体文件 | 字体文件 (.ttf/.otf) |

### ⚠️ 关键判断点

**询问用户**：
```
「请确认包类型：
- 预编译二进制 → {name}-bin（推荐，最常用）
- Git 开发版 → {name}-git（持续构建最新版）
- 稳定源码版 → {name}（无后缀，从源码编译）
- 字体文件 → {name}-font 或 font-{name}

该软件属于哪种类型？」
```

### 命名规则详解

#### Binary 包 (-bin) ⭐ 推荐

**适用场景**: 上游 GitHub Releases 提供预编译二进制

```bash
pkgname=myapp-bin        # ✅ 必须有 -bin 后缀
provides=('myapp')       # 提供 myapp 虚包
conflicts=('myapp')      # 与源码版冲突
```

**命名示例**:
- ✅ `opencli-bin`（预编译 CLI）
- ✅ `vscode-bin`（预编译应用）
- ✅ `nodejs-bin`（预编译运行时）
- ❌ `opencli`（缺少 -bin 后缀，会被认为是源码包）

#### VCS 包

**适用场景**: 用户需要最新开发版本，上游无稳定 Release

```bash
pkgname=myapp-git        # ✅ 必须有 -git 后缀
source=("git+${url}")    # Git 源码
provides=('myapp')       # 提供虚包
conflicts=('myapp')      # 与其他版本冲突
```

**命名示例**:
- ✅ `neovim-git`（最新开发版）
- ✅ `rust-git`（最新编译器）
- ❌ `neovim-dev`（错误后缀，应使用 -git）

#### Source 包（无后缀）

**适用场景**: 上游只提供源码 tarball，需编译

```bash
pkgname=myapp            # ✅ 无后缀
source=("${url}/releases/download/v${pkgver}/${source}.tar.gz")
```

**命名示例**:
- ✅ `gcc`（从源码编译）
- ✅ `python`（从源码编译）
- ❌ `gcc-bin`（如果实际是从源码编译）

#### Font 包

**适用场景**: 字体文件 (.ttf/.otf)

```bash
pkgname=myfont-font      # ✅ 或 font-myfont
arch=('any')             # 字体不依赖架构
depends=('fontconfig')   # 通常依赖 fontconfig
source=("${url}/font.ttf")
```

**命名示例**:
- ✅ `fira-code-font`
- ✅ `font-source-code-pro`
- ❌ `fira-code`（缺少 font 标识）

### 类型判断决策表

| 上游发布文件格式 | 推荐类型 | PKGBUILD 特征 |
|----------------|---------|--------------|
| 预编译二进制 (.exe/.AppImage/静态二进制) | **-bin** | 直接 `install -Dm755` |
| tar.gz 源码包 | **Source (无后缀)** | 需要 `build()` 函数 |
| Git 仓库（无 release） | **-git** | `source=("git+${url}")` |
| .ttf/.otf 字体文件 | **-font** | `arch=('any')` |

---

## 核心功能

### 1. 版本检测

**手动版本输入**: 用户指定版本号
**自动版本检测**: 从 GitHub Releases API 获取最新版本

```bash
# GitHub API 获取最新版本
curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r '.tag_name' | sed 's/^v//'
```

### 2. checksum 处理

**⚠️ 重要: checksum 在 GitHub Actions workflow 运行时通过 `updpkgsums` 自动生成，PKGBUILD 文件中使用 'SKIP' 占位符**

`updpkgsums` action 参数会:
1. 下载 source 文件
2. 计算并更新 sha256sums/md5sums
3. 更新 PKGBUILD 中的 checksum 字段

```yaml
- name: Publish to AUR
  uses: KSXGitHub/github-actions-deploy-aur@v4.1.2
  with:
    updpkgsums: true  # ✅ 自动计算 checksum
```

### 3. pkgrel 管理

- **新版本**: pkgver 更新，pkgrel 重置为 1
- **同版本修复**: 只 bump pkgrel

```bash
# 新版本
sed -i "s/^pkgver=.*/pkgver=${NEW_VERSION}/" PKGBUILD
sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD

# 同版本修复
CURRENT_REL=$(grep '^pkgrel=' PKGBUILD | cut -d'=' -f2)
NEW_REL=$((CURRENT_REL + 1))
sed -i "s/^pkgrel=.*/pkgrel=$NEW_REL/" PKGBUILD
```

### 3. AUR 同步

使用 `KSXGitHub/github-actions-deploy-aur` action 自动发布到 AUR:

```yaml
- name: Publish to AUR
  uses: KSXGitHub/github-actions-deploy-aur@v4.1.2
  with:
    pkgname: {pkgname}
    pkgbuild: ./{pkgname}/PKGBUILD
    updpkgsums: true
    commit_username: ${{ secrets.AUR_USERNAME }}
    commit_email: ${{ secrets.AUR_EMAIL }}
    ssh_private_key: ${{ secrets.AUR_SSH_PRIVATE_KEY }}
    commit_message: "Update to version {version}"
    ssh_keyscan_types: rsa,ecdsa,ed25519
```

---

## PKGBUILD 模板

### 基本 PKGBUILD 结构

**⚠️ sha256sums 使用 'SKIP' 占位符，workflow 运行时通过 `updpkgsums: true` 自动更新**

```bash
# Maintainer: {maintainer} <{email}>
pkgname={pkgname}
pkgver={version}  # workflow 会更新
pkgrel=1
pkgdesc="{description}"
arch=('x86_64')
url="{homepage}"
license=('{license}')
depends=({dependencies})
provides=('{provides}')
conflicts=('{conflicts}')
source_x86_64=("{url}/releases/download/v${pkgver}/{file}")
sha256sums_x86_64=('SKIP')  # ✅ workflow 通过 updpkgsums 自动计算

package() {
    # 包安装逻辑
}
```

### 多架构 PKGBUILD

**⚠️ checksum 使用 'SKIP'，workflow 自动计算**

```bash
pkgname={pkgname}
pkgver={version}
pkgrel=1
arch=('x86_64' 'aarch64')

source_x86_64=("{url}/releases/download/v${pkgver}/{file}-x86_64.tar.gz")
source_aarch64=("{url}/releases/download/v${pkgver}/{file}-aarch64.tar.gz")

sha256sums_x86_64=('SKIP')  # ✅ workflow 自动计算
sha256sums_aarch64=('SKIP')  # ✅ workflow 自动计算

package() {
    install -Dm755 {binary} "${pkgdir}/usr/bin/{name}"
}
```

### deb 包处理

**⚠️ checksum 使用 'SKIP'**

```bash
source_x86_64=("{file}.deb::${url}/releases/download/v${pkgver}/{deb_file}")
sha256sums_x86_64=('SKIP')  # workflow 自动计算

package() {
    # Extract deb package
    ar p "${srcdir}/${source_x86_64[0]}" data.tar.gz | tar xz -C "${pkgdir}"
    chmod -R u=rwX,go=rX "${pkgdir}"
}
```

---

## GitHub Actions Workflow

### 场景一：版本监控更新 ⭐ 默认

**适用场景**: 维护第三方项目的 AUR 包，定时检测上游版本变化

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
        uses: actions/checkout@v4

      - name: Get latest version
        id: get_version
        run: |
          if [ -n "${{ github.event.inputs.version }}" ]; then
            echo "version=${{ github.event.inputs.version }}" >> $GITHUB_OUTPUT
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
            if [ "${{ github.event.inputs.force }}" = "true" ]; then
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
            CURRENT_REL=$(grep '^pkgrel=' PKGBUILD | cut -d'=' -f2)
            NEW_REL=$((CURRENT_REL + 1))
            sed -i "s/^pkgrel=.*/pkgrel=$NEW_REL/" PKGBUILD
          else
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
        uses: KSXGitHub/github-actions-deploy-aur@v4.1.2
        with:
          pkgname: {pkgname}
          pkgbuild: ./{pkgname}/PKGBUILD
          updpkgsums: true
          post_process: bash /github/workspace/.github/scripts/prune-aur-workdir.sh .
          commit_username: ${{ secrets.AUR_USERNAME }}
          commit_email: ${{ secrets.AUR_EMAIL }}
          ssh_private_key: ${{ secrets.AUR_SSH_PRIVATE_KEY }}
          commit_message: "Update to version ${{ steps.get_version.outputs.version }}"
          ssh_keyscan_types: rsa,ecdsa,ed25519
```

---

### 场景二：编译发布一体化

**适用场景**: 自己的项目，Tag 推送 → 编译 → GitHub Release → 立即推送 AUR

**与场景一的区别**：
- 不需要版本检测，版本来自 git tag
- 编译和发布在同一次 workflow 中完成
- 适用于项目作者维护自己的 AUR 包

#### Workflow 模板

```yaml
name: Release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - goos: linux
            goarch: amd64
            output: myapp-linux-amd64
          - goos: linux
            goarch: arm64
            output: myapp-linux-arm64
          - goos: darwin
            goarch: amd64
            output: myapp-darwin-amd64
          - goos: darwin
            goarch: arm64
            output: myapp-darwin-arm64
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-go@v4
        with:
          go-version: stable
      
      - name: Build
        env:
          GOOS: ${{ matrix.goos }}
          GOARCH: ${{ matrix.goarch }}
        run: |
          go build -ldflags="-s -w -X main.version=${{ github.ref_name }}" \
            -o dist/${{ matrix.output }}
      
      - uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.output }}
          path: dist/${{ matrix.output }}

  release:
    name: Create Release
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/download-artifact@v4
        with:
          path: dist/
          merge-multiple: true
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: dist/*
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  publish-aur:
    name: Publish to AUR
    needs: release
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Extract version
        id: version
        run: echo "version=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
      
      - name: Update PKGBUILD
        run: |
          cd {pkgname}
          sed -i "s/^pkgver=.*/pkgver=${{ steps.version.outputs.version }}/" PKGBUILD
          sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
      
      - name: Publish to AUR
        uses: KSXGitHub/github-actions-deploy-aur@v4.1.2
        with:
          pkgname: {pkgname}
          pkgbuild: ./{pkgname}/PKGBUILD
          updpkgsums: true
          commit_username: ${{ secrets.AUR_USERNAME }}
          commit_email: ${{ secrets.AUR_EMAIL }}
          ssh_private_key: ${{ secrets.AUR_SSH_PRIVATE_KEY }}
          commit_message: "Update to version ${{ steps.version.outputs.version }}"
          ssh_keyscan_types: rsa,ecdsa,ed25519
```

#### 关键差异说明

| 配置项 | 场景一（版本监控） | 场景二（编译发布） |
|--------|------------------|-------------------|
| **触发条件** | `schedule` + `workflow_dispatch` | `push: tags: v*` |
| **版本来源** | GitHub API 检测 | git tag 直接提取 |
| **编译步骤** | 无（使用上游 release） | 需要 build job |
| **发布顺序** | 检测 → 更新 → 推送 | 编译 → Release → 推送 |
| **适用包类型** | `-bin`（预编译） | `-bin`（自己的编译产物） |

---

### 场景三：GoReleaser 集成 ⭐

**适用场景**: Go/Rust/Zig 等项目，使用 GoReleaser 自动化发布流程

**优势**：
- 一份 `.goreleaser.yml` 配置编译、打包、发布
- 自动支持多平台编译
- 同时发布 `-bin` 包和源码包
- checksum 自动计算

#### 配置参考文档

详细配置请查阅 [references/goreleaser-aur.md](references/goreleaser-aur.md)

#### 快速配置示例

**二进制包 (`aurs`)**：
```yaml
# .goreleaser.yml
aurs:
  - name: myapp-bin              # 自动添加 -bin 后缀
    homepage: "https://example.com/"
    description: "My application"
    maintainers:
      - "Your Name <your@email.com>"
    license: "MIT"
    private_key: "{{ .Env.AUR_KEY }}"
    git_url: "ssh://aur@aur.archlinux.org/myapp-bin.git"
    depends:
      - curl
    package: |-
      install -Dm755 "./myapp" "${pkgdir}/usr/bin/myapp"
      install -Dm644 "./LICENSE" "${pkgdir}/usr/share/licenses/myapp/LICENSE"
```

**源码包 (`aur_sources`)**：
```yaml
# .goreleaser.yml
aur_sources:
  - name: myapp                  # 移除 -bin 后缀
    homepage: "https://example.com/"
    description: "My application"
    maintainers:
      - "Your Name <your@email.com>"
    license: "MIT"
    private_key: "{{ .Env.AUR_KEY }}"
    git_url: "ssh://aur@aur.archlinux.org/myapp.git"
    makedepends:
      - go
      - git
    depends:
      - curl
    build_script: |-
      cd "${pkgname}_${pkgver}"
      go build -ldflags="-w -s -X main.version=${pkgver}" .
    package: |-
      cd "${pkgname}_${pkgver}"
      install -Dsm755 ./myapp "${pkgdir}/usr/bin/myapp"
```

#### GitHub Actions 配合

```yaml
name: Release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  goreleaser:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - uses: actions/setup-go@v4
        with:
          go-version: stable
      
      - uses: goreleaser/goreleaser-action@v6
        with:
          distribution: goreleaser
          version: "~> v2"
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          AUR_KEY: ${{ secrets.AUR_KEY }}
```

#### `aurs` vs `aur_sources` 对比

| 配置项 | `aurs` (二进制包) | `aur_sources` (源码包) |
|--------|------------------|----------------------|
| **包名后缀** | 强制 `-bin` | 移除 `-bin` |
| **构建方式** | 直接安装预编译二进制 | 从源码编译 |
| **必需参数** | `package` 脚本 | `build_script` + `package` |
| **依赖类型** | `depends` (运行时) | `depends` + `makedepends` (构建时) |
| **适用项目** | 任意预编译项目 | Go/Rust/Zig 等可编译项目 |

---

## Secrets 配置

需要在 GitHub 仓库配置以下 Secrets:

| Secret | 说明 |
|--------|------|
| `AUR_USERNAME` | AUR 用户名 |
| `AUR_EMAIL` | AUR 邮箱 |
| `AUR_SSH_PRIVATE_KEY` | AUR SSH 私钥 |

### SSH 密钥配置

```bash
# 生成 SSH 密钥
ssh-keygen -f aur_key -t ed25519 -C "your@email.com"

# 上传公钥到 AUR
# https://aur.archlinux.org/account/

# 将私钥添加到 GitHub Secrets
cat aur_key  # 复制完整内容，包括 BEGIN/END 行
```

### ⚠️ 首次发布前必须创建 AUR 仓库

**首次发布新包时，必须先克隆并初始化 AUR 仓库**:

```bash
# 1. 克隆空的 AUR 仓库（创建新包）
git clone ssh://aur.archlinux.org/{pkgname}.git /tmp/{pkgname}

# 2. 进入目录，添加基本文件
cd /tmp/{pkgname}

# 3. 创建 PKGBUILD（可以从模板复制）
cp ~/your-project/PKGBUILD .

# 4. 生成 .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# 5. 配置 git 用户信息
git config user.name "your-aur-username"
git config user.email "your@email.com"

# 6. 提交并推送
git add PKGBUILD .SRCINFO
git commit -m "Initial commit: {pkgname}"
git push origin master
```

**注意**: GitHub Actions workflow 只能推送修改，不能创建新仓库。首次发布必须手动完成以上步骤。

---

## 工作流程

### Phase 0: 首次发布检测与引导 ⭐ 新增

**输入**: 用户请求（创建新 PKGBUILD）
**输出**: 发布方式选择 + 初始版本号策略

#### Step 0.1: 检测包状态

**⚠️ 关键检查点**: 确定是否首次发布

```bash
# 检查 AUR 中是否存在该包
curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg={pkgname}" | jq -r '.resultcount'
# 0 = 不存在（首次发布）
# 1+ = 已存在（更新流程）
```

| 状态 | 处理方式 |
|------|---------|
| **已存在** | 跳过 Phase 0，进入正常更新流程（Phase 1） |
| **不存在** | 进入首次发布引导流程 |

#### Step 0.2: 引导用户选择发布方式

**⚠️ 必须询问用户**:

```
询问用户：
「检测到该包尚未在 AUR 发布，属于首次发布。

有两种方式完成首次发布：

【方案 A】GitHub 自动发布（推荐）
- 自动获取最新版本，设置初始版本号（patch version 回退）
- GitHub Action 检测版本变化后自动发布到 AUR
- checksum 由 workflow 自动计算
- 简单快捷，无需手动操作 AUR 仓库

【方案 B】传统手动发布
- 手动克隆 AUR 仓库
- 创建 PKGBUILD 和 .SRCINFO
- 手动 SSH 推送创建仓库
- 需要熟悉 AUR 操作流程

是否选择 GitHub 自动发布？」
```

#### Step 0.3: 确定初始版本号（方案 A）

**获取最新版本并计算初始版本**:

```bash
# 获取上游最新版本
LATEST_VERSION=$(curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r '.tag_name' | sed 's/^v//')

# 计算 patch version 回退（版本格式 X.Y.Z）
# 示例：1.2.5 → 1.2.4
INITIAL_VERSION=$(echo "$LATEST_VERSION" | awk -F. '{print $1"."$2"."$3-1}')
```

**版本回退策略**:

| 版本格式 | 最新版本 | 初始版本 | 算法 |
|---------|---------|---------|------|
| X.Y.Z | 1.2.5 | 1.2.4 | `$3-1` |
| YYYY.MM.DD | 2024.01.15 | 2024.01.14 | 最后部分 -1 |
| vX.Y.Z | v1.2.5 | 1.2.4 | 去掉 v 前缀后 -1 |
| 单数字 | 5 | 4 | 直接 -1 |

**无法获取版本号时**:

```
询问用户：
「无法自动获取上游版本号。

请手动输入初始版本号：
- 如果知道最新版本：输入最新版本减一
- 如果不确定：输入一个明显低于预期的版本（如 0.0.1）

初始版本号：」
```

#### Step 0.4: Secrets 配置检查

**⚠️ 首次发布前必须确认 Secrets 已配置**:

```
询问用户：
「首次发布需要 GitHub Secrets 配置：

| Secret | 说明 |
|--------|------|
| AUR_USERNAME | AUR 用户名 |
| AUR_EMAIL | AUR 邮箱 |
| AUR_SSH_PRIVATE_KEY | AUR SSH 私钥 |

SSH 公钥必须已上传到 AUR（https://aur.archlinux.org/account/）

是否已配置完成？」
```

#### Step 0.5: 生成初始 PKGBUILD

**使用初始版本号生成 PKGBUILD**:

- `pkgver` 使用初始版本号（低于最新）
- `sha256sums` 使用 `'SKIP'`（workflow 自动计算）
- 提交后用户触发 workflow，自动发布最新版本

**首次发布完成标志**:
1. 提交初始 PKGBUILD 到 GitHub
2. 用户手动触发 workflow 或等待定时触发
3. Workflow 检测版本变化，自动更新并发布到 AUR

**⚠️ 检查点**: 详细流程请参阅 [references/initial-publish-guide.md](references/initial-publish-guide.md)

---

### Phase 1: 信息收集与前置检查

**输入**: 用户请求（创建/更新 PKGBUILD）
**输出**: 包类型确认 + 上游仓库信息 + AUR 仓库状态确认

#### Step 1.0: 确认包类型

**⚠️ 关键检查点**: 确认包类型决定了命名规则和 PKGBUILD 结构

```
询问用户：
「请确认包类型：
- 预编译二进制 → {name}-bin（推荐，直接安装）
- Git 开发版 → {name}-git（从源码构建最新版）
- 稳定源码版 → {name}（无后缀，从源码编译）
- 字体文件 → {name}-font 或 font-{name}

该软件属于哪种类型？」
```

#### Step 1.1: 确认上游仓库信息

**⚠️ 检查点**: 在创建之前，必须确认以下信息：

| 必需信息 | 说明 | 用户确认方式 |
|---------|------|-------------|
| GitHub owner/repo | 上游仓库地址 | 用户提供或从 URL 提取 |
| 发布文件格式 | deb、tar.gz、二进制等 | 分析 GitHub Releases |
| 架构支持 | x86_64、aarch64 或两者 | 分析发布文件命名 |
| 包名称 | 用于 pkgname（推荐 `-bin` 后缀） | 用户确认 |
| 运行时依赖 | depends 列表 | 使用 ldd/namcap 探测或询问 |

**依赖探测工具推荐**:
- `ldd <binary>` - 查看动态链接库依赖
- `objdump -p <binary> | grep NEEDED` - 查看需要的动态库
- `namcap PKGBUILD` - 验证依赖声明是否正确

```
询问用户：
「请确认以下信息：
- GitHub 仓库: {owner}/{repo}
- 发布文件格式: {format}
- 架构支持: {archs}
- 包名称: {pkgname}-bin
- 运行时依赖: {depends}（可使用 ldd 探测）

是否正确？」
```

#### Step 1.2: 检查 AUR 仓库状态

**⚠️ 关键检查点**: 确认 AUR 仓库是否存在

```bash
# 检查包是否已存在
curl -s "https://aur.archlinux.org/packages/{pkgname}" | grep -q "Package Details"
```

| 状态 | 处理方式 |
|------|---------|
| **已存在** | 直接进入更新流程 |
| **不存在** | 提示用户需要首次手动创建 |

```
如果包不存在：
「⚠️ 该包在 AUR 中不存在，首次发布需要手动操作：
1. 克隆空仓库: git clone ssh://aur.archlinux.org/{pkgname}.git
2. 添加 PKGBUILD 和 .SRCINFO
3. 推送创建仓库

是否需要我提供详细步骤？」
```

---

### Phase 2: 文件生成

**输入**: Phase 1 确认的信息
**输出**: PKGBUILD + GitHub Workflow + 相关文件

#### Step 2.1: 选择包类型模板

| 包类型 | 模板选择 | source 格式 |
|-------|---------|-------------|
| 二进制 | 直接安装 | `{url}/{binary}` |
| deb 包 | ar 解压 | `{file}.deb::${url}/{deb_file}` |
| tar.gz | 解压安装 | `{url}/{file}.tar.gz` |
| AppImage | 单文件 | `{url}/{file}.AppImage` |

**⚠️ 检查点**: checksum 使用策略确认：

```
询问用户：
「PKGBUILD 中的 checksum 使用 SKIP 占位符，
GitHub Actions workflow 通过 updpkgsums: true 自动计算。
是否继续？」
```

#### Step 2.2: 生成 PKGBUILD

根据包类型生成对应的 PKGBUILD，确保：
- `sha256sums=('SKIP')` 或 `sha256sums_x86_64=('SKIP')`
- 正确的 `arch` 声明
- `provides` 和 `conflicts` 声明

#### Step 2.3: 生成 GitHub Workflow

生成自动更新 workflow，包含：
- `workflow_dispatch`: 手动触发 + 版本输入 + force 参数
- `schedule`: 定时检查（推荐每12小时）
- `updpkgsums: true`: 自动 checksum
- AUR 发布步骤

---

### Phase 3: 验证与发布

**输入**: Phase 2 生成的文件
**输出**: 验证结果 + 发布

#### Step 3.1: 本地验证（推荐）

```bash
# 验证 PKGBUILD
namcap PKGBUILD

# 生成 .SRCINFO
makepkg --printsrcinfo > .SRCINFO
```

**⚠️ 检查点**: 验证失败时询问用户：

```
如果 namcap 报错：
「验证发现问题：{error}
是否继续提交，或先修复问题？」
```

#### Step 3.2: 提交到 GitHub 仓库

```bash
git add {pkgname}/PKGBUILD {pkgname}/.SRCINFO .github/workflows/update-{pkgname}.yml
git commit -m "feat: add {pkgname} AUR package with auto-update workflow"
git push
```

#### Step 3.3: AUR 发布（首次需手动）

| 场景 | 操作 |
|------|------|
| **首次发布** | 参考 `references/aur-deploy-action.md` 手动创建 |
| **更新版本** | workflow 自动触发 AUR 发布 |

---

## 边界条件与错误处理

| 异常情况 | 处理方式 | Fallback |
|---------|---------|---------|
| AUR SSH 认证失败 | 检查私钥格式和公钥上传 | 提示用户检查 Secrets |
| GitHub API 不可达 | 提示用户手动输入版本 | 使用 workflow_dispatch 输入 |
| 发布文件不存在 | 检查 URL 格式和版本号 | 询问用户确认文件命名 |
| pkgrel bump 需求 | 同版本修复 | workflow force 参数 |
| deb 包权限问题 | chmod 修复 | `chmod -R u=rwX,go=rX` |
| 多架构文件缺失 | 只有单架构 | 询问用户是否降级 |
| AUR 包名冲突 | 搜索 AUR 确认 | 建议使用 `-bin` 后缀 |

---

## 决策速查表

| 场景 | 决策 |
|------|------|
| **首次发布检测** | **必须检查**: curl AUR RPC API 确认是否存在 |
| **首次发布方式** | **必须询问**: 方案 A（GitHub 自动）或方案 B（手动） |
| **初始版本号** | **自动计算**: patch version 回退（最新版本 -1） |
| **版本号无法获取** | **询问用户**: 手动输入初始版本号 |
| **Secrets 配置** | **首次必须**: AUR_USERNAME/AUR_EMAIL/AUR_SSH_PRIVATE_KEY |
| **SSH 公钥上传** | **首次必须**: 已上传到 AUR 账户 |
| **包类型判断** | **必须询问**: -bin/-git/无后缀/-font？ |
| 用户未提供包名后缀 | **推荐**: 使用 `-bin` 后缀（预编译包最常见） |
| AUR 包是否已存在 | **必须检查**: curl AUR API 或询问用户 |
| checksum 是否预填 | **使用 SKIP**: workflow 通过 updpkgsums 计算 |
| 是否需要 .install 文件 | **可选**: 有 post_install 钩子时添加 |
| 定时更新频率 | **推荐**: 每12小时 (`0 */12 * * *`) |
| 字体包架构 | **使用**: `arch=('any')`（字体不依赖架构） |

---

## 依赖项探测工具

### 1. ldd - 动态链接库依赖

**适用场景**: 分析预编译二进制文件的动态链接库依赖

```bash
# 查看二进制的动态依赖
ldd /path/to/binary

# 示例输出：
# linux-vdso.so.1 (0x00007ff...)
# libc.so.6 => /usr/lib/libc.so.6 (0x00007f...)
# libpthread.so.0 => /usr/lib/libpthread.so.0 (0x00007f...)
```

**⚠️ 注意**: `ldd` 只显示动态链接库，不包含其他依赖（如 Python 模块、字体等）。

### 2. namcap - PKGBUILD 依赖分析

**⭐ 推荐**: `namcap` 是 AUR 官方验证工具，能自动检测缺失的依赖和冗余依赖

```bash
# 安装 namcap
sudo pacman -S namcap

# 分析 PKGBUILD
namcap PKGBUILD

# 分析已构建的包
namcap {pkgname}-{version}-1-x86_64.pkg.tar.zst

# 示例输出：
# PKGBUILD (myapp-bin): W: Dependency glibc detected but not declared
# PKGBUILD (myapp-bin): W: Dependency libopenssl detected but not declared
```

**namcap 检测类型**:
- 缺失依赖（未声明但二进制需要）
- 冗余依赖（已声明但实际不需要）
- 架构不匹配（如 `arch=('x86_64')` 但二进制是 `aarch64`）

### 3. objdump - 深度分析

**适用场景**: 查看 NEEDED 动态库列表（比 ldd 更精确）

```bash
# 查看 NEEDED 动态库
objdump -p /path/to/binary | grep NEEDED

# 示例输出：
# NEEDED               libc.so.6
# NEEDED               libpthread.so.0
# NEEDED               libssl.so.3
# NEEDED               libcrypto.so.3
```

### 4. pactree - 已安装包的依赖树

**适用场景**: 查看已安装包的完整依赖树

```bash
# 安装 pactree（属于 pacman-contrib）
sudo pacman -S pacman-contrib

# 查看依赖树
pactree myapp

# 反向依赖树（哪些包依赖 myapp）
pactree -r myapp
```

### 5. pscache - Python 依赖探测

**适用场景**: Python 应用的依赖探测

```bash
# 查看 Python 脚本的导入
grep -r "import " /path/to/app/ | grep -v "__pycache__"

# 使用 pipreqs 自动生成 requirements
pip install pipreqs
pipreqs /path/to/app/
```

### 依赖探测工作流

**⚠️ 检查点**: 创建 PKGBUILD 时，推荐按以下顺序探测依赖

```
1. 使用 ldd/objdump 分析二进制动态依赖
2. 检查应用文档/README 确认运行时依赖
3. 构建并使用 namcap 验证依赖声明
4. 根据 namcap 输出修正 PKGBUILD
```

**示例依赖探测流程**:

```bash
# Step 1: 分析二进制
ldd ./myapp-binary | grep "=> /usr/lib" | awk '{print $1}'

# Step 2: 转换为 Arch 包名
# libssl.so.3 → openssl
# libcrypto.so.3 → openssl
# libcurl.so.4 → curl

# Step 3: 写入 PKGBUILD
depends=('openssl' 'curl' 'glibc')

# Step 4: namcap 验证
namcap PKGBUILD

# Step 5: 修正后重新构建
makepkg -sf
namcap myapp-bin-1.0.0-1-x86_64.pkg.tar.zst
```

---

## 常用命令

### 本地验证

```bash
# 生成 .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# 验证 PKGBUILD
namcap PKGBUILD

# 本地构建测试
makepkg -sf

# 安装测试
sudo pacman -U {pkgname}-{version}-1-x86_64.pkg.tar.zst
```

### 版本检测

```bash
# 获取最新版本
curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r '.tag_name' | sed 's/^v//'

# 检查当前版本
grep '^pkgver=' PKGBUILD | cut -d'=' -f2
```

---

## 包类型处理

### 二进制包 (bin)

**⚠️ checksum 使用 'SKIP'，workflow 通过 `updpkgsums: true` 自动计算**

```bash
source=("{url}/releases/download/v${pkgver}/{binary}")
sha256sums=('SKIP')  # ✅ workflow 自动计算

package() {
    install -Dm755 {binary} "${pkgdir}/usr/bin/{name}"
}
```

### deb 包转换

从 deb 包提取文件:

```bash
source=("{file}.deb::${url}/releases/download/v${pkgver}/{deb_file}")
sha256sums=('SKIP')  # workflow 自动计算

package() {
    ar p "${srcdir}/${source}" data.tar.gz | tar xz -C "${pkgdir}"
    chmod -R u=rwX,go=rX "${pkgdir}"
}
```

### tar.gz 包

解压并安装:

```bash
source=("{url}/releases/download/v${pkgver}/{file}.tar.gz")
sha256sums=('SKIP')  # workflow 自动计算

package() {
    install -Dm755 ${srcdir}/{binary} "${pkgdir}/usr/bin/{name}"
}
```

---

## 最佳实践

### ✅ 推荐做法

1. **使用 `-bin` 后缀**: 预编译包使用 `{name}-bin`
2. **提供 provides/conflicts**: 与官方包冲突声明
3. **定时更新**: 设置 schedule 自动检查版本
4. **手动触发**: 提供 workflow_dispatch 支持手动指定版本
5. **pkgrel 管理**: 同版本修复只 bump pkgrel

### ❌ 避免的做法

1. **硬编码版本**: 不更新 pkgver
2. **缺少依赖声明**: 导致安装失败
3. **跳过验证**: 不运行 namcap
4. **忽略错误**: curl 失败不检查
5. **不更新 .SRCINFO**: AUR 无法正确索引

---

## 触发场景

使用此技能的场景:

- 「帮我更新 AUR 中的 xxx 包」
- 「创建一个新的 PKGBUILD」
- 「发布 xxx 到 AUR」
- 「更新 Arch Linux 包版本」
- 「配置 AUR 自动发布」
- 「创建 xxx 的 AUR workflow」

---

## 输入要求

创建/更新 PKGBUILD 时，请提供:

1. **上游仓库信息**: GitHub owner/repo
2. **包名称**: 用于 pkgname
3. **发布文件格式**: deb、rpm、tar.gz、二进制等
4. **架构支持**: x86_64、aarch64 或两者
5. **版本号**: 手动指定或自动检测
6. **依赖信息**: 运行时依赖

---

## 输出格式

技能将生成:

1. **PKGBUILD 文件**: 包构建定义
2. **.install 文件**: 安装钩子（可选）
3. **GitHub Workflow**: `.github/workflows/update-xxx.yml`
4. **更新说明**: commit message 格式
5. **验证结果**: namcap 输出

详见各 reference 文档获取完整模板和示例。