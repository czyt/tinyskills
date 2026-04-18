# GoReleaser AUR 发布集成

GoReleaser 支持两种 AUR 发布方式：二进制包和源码包。

---

## 场景对比

| 场景 | 配置项 | 包名后缀 | 适用情况 |
|------|--------|---------|---------|
| **二进制包** | `aurs` | `-bin` (强制) | 预编译二进制 |
| **源码包** | `aur_sources` | 无后缀 (移除 `-bin`) | 从源码构建 |

---

## 一、二进制包 (aurs)

适用于发布预编译二进制到 AUR，GoReleaser 会自动添加 `-bin` 后缀。

### 配置示例

```yaml
# .goreleaser.yml
aurs:
  - name: myapp-bin           # 包名，自动添加 -bin 后缀
    homepage: "https://example.com/"
    description: "My awesome application"
    maintainers:
      - "Your Name <your@email.com>"
    license: "MIT"
    private_key: "{{ .Env.AUR_KEY }}"
    git_url: "ssh://aur@aur.archlinux.org/myapp-bin.git"
    
    # 包关系
    provides:
      - myapp
    conflicts:
      - myapp
    depends:
      - curl
    
    # 安装脚本
    package: |-
      # bin
      install -Dm755 "./myapp" "${pkgdir}/usr/bin/myapp"
      # license
      install -Dm644 "./LICENSE" "${pkgdir}/usr/share/licenses/myapp/LICENSE"
      # completions
      mkdir -p "${pkgdir}/usr/share/bash-completion/completions/"
      install -Dm644 "./completions/myapp.bash" "${pkgdir}/usr/share/bash-completion/completions/myapp"
    
    # 发布控制
    skip_upload: false         # true 则只生成文件不推送
    disable: "{{ .IsSnapshot }}"  # 快照版本禁用
    
    # Git 提交作者
    commit_author:
      name: goreleaserbot
      email: bot@goreleaser.com
```

### 关键参数

| 参数 | 说明 | 必需 |
|------|------|------|
| `name` | 包名（会强制添加 `-bin`） | ✓ |
| `private_key` | AUR SSH 私钥（环境变量引用） | ✓ |
| `git_url` | AUR Git 仓库 URL | ✓ |
| `homepage` | 项目主页 | ✓ |
| `description` | 包描述 | ✓ |
| `depends` | 运行时依赖 | |
| `provides` | 提供的虚包 | |
| `conflicts` | 冲突的包 | |
| `package` | 安装脚本（覆盖默认） | |
| `skip_upload` | 跳过推送，只生成文件 | |

---

## 二、源码包 (aur_sources)

适用于从源码构建的包，GoReleaser 会移除 `-bin` 后缀。

### 配置示例

```yaml
# .goreleaser.yml
aur_sources:
  - name: myapp              # 包名，移除 -bin 后缀
    homepage: "https://example.com/"
    description: "My awesome application"
    maintainers:
      - "Your Name <your@email.com>"
    license: "MIT"
    private_key: "{{ .Env.AUR_KEY }}"
    git_url: "ssh://aur@aur.archlinux.org/myapp.git"
    
    # 构建依赖
    makedepends:
      - go
      - git
    
    # 运行时依赖
    depends:
      - curl
    
    # 构建脚本
    build_script: |-
      cd "${pkgname}_${pkgver}"
      export CGO_CPPFLAGS="${CPPFLAGS}"
      export CGO_CFLAGS="${CFLAGS}"
      export CGO_CXXFLAGS="${CXXFLAGS}"
      export CGO_LDFLAGS="${LDFLAGS}"
      export GOFLAGS="-buildmode=pie -trimpath -mod=readonly -modcacherw"
      go build -ldflags="-w -s -buildid='' -linkmode=external -X main.version=${pkgver}" .
      chmod +x ./myapp
    
    # 安装脚本
    package: |-
      cd "${pkgname}_${pkgver}"
      install -Dsm755 ./myapp "${pkgdir}/usr/bin/myapp"
      install -Dm644 ./LICENSE "${pkgdir}/usr/share/licenses/myapp/LICENSE"
```

### 关键参数（与 aurs 的区别）

| 参数 | 说明 | 源码包必需 |
|------|------|-----------|
| `makedepends` | 构建依赖（如 `go`, `git`） | ✓ |
| `build_script` | 构建脚本 | ✓ |
| `package` | 安装脚本 | ✓ |

---

## 三、环境变量配置

### GitHub Actions Secrets

需要在 GitHub 仓库设置以下 Secrets：

| Secret | 说明 |
|--------|------|
| `AUR_KEY` | AUR SSH 私钥（无密码保护） |

### SSH 密钥生成

```bash
# 生成无密码保护的 SSH 密钥
ssh-keygen -f aur_key -t ed25519 -C "your@email.com" -N ""

# 上传公钥到 AUR
# https://aur.archlinux.org/account/

# 将私钥内容添加到 GitHub Secret (AUR_KEY)
cat aur_key
```

---

## 四、GitHub Actions Workflow

### 使用 GoReleaser 的发布流程

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
      - name: Checkout
        uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Set up Go
        uses: actions/setup-go@v6
        with:
          go-version: stable

      - name: Run GoReleaser
        uses: goreleaser/goreleaser-action@v7
        with:
          distribution: goreleaser
          version: "~> v2"
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          AUR_KEY: ${{ secrets.AUR_KEY }}
```

---

## 五、发布流程对比

### GoReleaser vs 手动 GitHub Action

| 方面 | GoReleaser | 手动 GitHub Action |
|------|------------|-------------------|
| **配置复杂度** | `.goreleaser.yml` 一处配置 | 需分开配置 workflow + PKGBUILD |
| **多平台支持** | 自动编译多平台二进制 | 需手动 matrix 配置 |
| **AUR 包类型** | 支持 `-bin` 和源码包 | 主要 `-bin` |
| **checksum** | 自动计算 | 需 `updpkgsums` |
| **适用项目** | Go/Rust/Bun/Python 等 | 任意语言 |

### 选择建议

| 场景 | 推荐方式 |
|------|---------|
| **Go/Rust 项目** | GoReleaser ⭐ |
| **任意预编译二进制** | 手动 GitHub Action |
| **源码构建包** | GoReleaser `aur_sources` |
| **第三方项目维护** | 手动版本监控 workflow |

---

## 六、注意事项

1. **私钥无密码保护**: GoReleaser 要求私钥不能有密码
2. **首次发布需手动**: AUR 仓库需先手动创建
3. **包名后缀规则**: `aurs` 强制 `-bin`，`aur_sources` 移除 `-bin`
4. **版本提取**: GoReleaser 自动从 git tag 提取版本
5. **快照版本**: `disable: "{{ .IsSnapshot }}"` 禁用快照发布

---

## 参考资料

- GoReleaser AUR 文档: https://goreleaser.com/customization/publish/aur/
- GoReleaser AUR Sources 文档: https://goreleaser.com/customization/publish/aursources/
- AUR 提交指南: https://wiki.archlinux.org/title/AUR_submission_guidelines
- PKGBUILD 参考: https://wiki.archlinux.org/title/PKGBUILD