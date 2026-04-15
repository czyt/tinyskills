---
name: homebrew-github-publish
description: Homebrew Tap GitHub 发布助手 - 自动更新 Casks 和 Formulas 版本并发布到 GitHub Tap 仓库。支持手动版本输入、自动版本检测、sha256 校验和计算、多架构支持（arm64/x64）。触发词：更新 Homebrew Cask、发布到 Homebrew Tap、更新 Formula 版本、创建 Homebrew 包。
---

# Homebrew Tap GitHub 发布助手

协助将软件版本更新到 Homebrew Tap 仓库，自动化版本检测、sha256 校验和计算和 GitHub 发布流程。

## Reference Documents

| Document | Content |
|----------|---------|
| [references/cask-template.md](references/cask-template.md) | Cask 模板语法与结构 |
| [references/formula-template.md](references/formula-template.md) | Formula 模板语法与结构 |
| [references/workflow-template.md](references/workflow-template.md) | GitHub Actions workflow 模板 |
| [references/version-detection.md](references/version-detection.md) | 版本检测策略 |
| [references/best-practices.md](references/best-practices.md) | 最佳实践与常见问题 |
| [references/real-world-examples.md](references/real-world-examples.md) | 真实项目示例（含 GitHub Action 实例） |

---

## 仓库结构

### Homebrew Tap 标准布局

```
homebrew-tap/
├── Casks/                    # macOS 应用包定义
│   ├── app1.rb
│   ├── app2.rb
│   └── ...
├── Formula/                  # 命令行工具定义
│   ├── tool1.rb
│   ├── tool2.rb
│   └── ...
└── .github/
    └── workflows/
        ├── update-app1-version.yml
        ├── update-tool1-version.yml
        └── ...
```

---

## 核心功能

### 1. 版本检测

**手动版本输入**: 用户指定版本号
**自动版本检测**: 从 GitHub Releases API 获取最新版本

```bash
# GitHub API 获取最新版本
curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r '.tag_name' | sed 's/^v//'
```

### 2. sha256 校验和计算

**⚠️ 重要: sha256 在 GitHub Actions workflow 运行时自动计算和更新，Cask/Formula 文件中不需要预先填写真实的 sha256**

workflow 会:
1. 下载发布文件
2. 计算 sha256
3. 使用 sed 命令更新 Cask/Formula 文件中的 sha256

```bash
# Workflow 中计算 sha256
sha256sum /tmp/file.dmg | awk '{print $1}'

# Workflow 中更新 Cask 文件
sed -i '/on_arm do/,/end/{s/sha256 ".*"/sha256 "${{ steps.checksums.outputs.arm64_sha256 }}"/}' Casks/{name}.rb
```

### 3. 多架构支持

- **arm64 (Apple Silicon)**: `on_arm do`
- **x64 (Intel)**: `on_intel do`

---

## Cask 模板

### 基本 Cask 结构

**⚠️ sha256 使用占位符，workflow 运行时会自动更新**

```ruby
cask "{name}" do
  version "{version}"  # workflow 会更新

  on_arm do
    sha256 "PLACEHOLDER"  # workflow 运行时自动计算并替换
    url "https://github.com/{owner}/{repo}/releases/download/v#{version}/{file}-#{version}-mac-arm64.dmg"
  end

  on_intel do
    sha256 "PLACEHOLDER"  # workflow 运行时自动计算并替换
    url "https://github.com/{owner}/{repo}/releases/download/v#{version}/{file}-#{version}-mac-x64.dmg"
  end

  name "{app_name}"
  desc "{description}"
  homepage "https://github.com/{owner}/{repo}"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "{app_name}.app"
end
```

### 单架构 Cask

**⚠️ sha256 使用占位符**

```ruby
cask "{name}" do
  version "{version}"
  sha256 "PLACEHOLDER"  # workflow 自动更新

  url "https://github.com/{owner}/{repo}/releases/download/v#{version}/{file}-#{version}.dmg"

  name "{app_name}"
  desc "{description}"
  homepage "https://github.com/{owner}/{repo}"

  app "{app_name}.app"
end
```

---

## Formula 模板

### 基本 Formula 结构

**⚠️ sha256 使用占位符，workflow 运行时自动计算和更新**

```ruby
class {ClassName} < Formula
  desc "{description}"
  homepage "{homepage}"
  version "{version}"
  license "{license}"

  on_macos do
    if Hardware::CPU.arm?
      url "{arm64_url}"
      sha256 "PLACEHOLDER"  # workflow 自动更新

      def install
        bin.install "{binary}" => "{name}"
      end
    end

    if Hardware::CPU.intel?
      url "{x64_url}"
      sha256 "PLACEHOLDER"  # workflow 自动更新

      def install
        bin.install "{binary}" => "{name}"
      end
    end
  end

  def caveats
    <<~EOS
      {name} has been installed!
      ...
    EOS
  end

  test do
    system "#{bin}/{name}", "--version"
  end
end
```

---

## GitHub Actions Workflow

### 标准 Workflow 模板

```yaml
name: Update {AppName} Version

on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version number (e.g., 1.0.0). Leave empty to auto-detect."
        required: false
        type: string
  schedule:
    - cron: "0 */12 * * *"

jobs:
  update-cask:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Get latest version
        id: version_check
        run: |
          CURRENT_VERSION=$(grep 'version "' Casks/{name}.rb | sed 's/.*version "\(.*\)".*/\1/')
          if [ -n "${{ inputs.version }}" ]; then
            NEW_VERSION="${{ inputs.version }}"
          else
            NEW_VERSION=$(curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r '.tag_name' | sed 's/^v//')
          fi
          echo "current_version=$CURRENT_VERSION" >> $GITHUB_OUTPUT
          echo "new_version=$NEW_VERSION" >> $GITHUB_OUTPUT
          echo "should_update=$([[ '$CURRENT_VERSION' != '$NEW_VERSION' ]] && echo true || echo false)" >> $GITHUB_OUTPUT

      - name: Download files and calculate checksums
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          # Download arm64 file
          curl -f -L -o /tmp/{name}-arm64.dmg "https://github.com/{owner}/{repo}/releases/download/v${{ steps.version_check.outputs.new_version }}/{file}-v${{ steps.version_check.outputs.new_version }}-mac-arm64.dmg"
          # Download x64 file
          curl -f -L -o /tmp/{name}-x64.dmg "https://github.com/{owner}/{repo}/releases/download/v${{ steps.version_check.outputs.new_version }}/{file}-v${{ steps.version_check.outputs.new_version }}-mac-x64.dmg"
          # Calculate checksums
          ARM64_SHA256=$(sha256sum /tmp/{name}-arm64.dmg | awk '{print $1}')
          X64_SHA256=$(sha256sum /tmp/{name}-x64.dmg | awk '{print $1}')
          echo "arm64_sha256=$ARM64_SHA256" >> $GITHUB_OUTPUT
          echo "x64_sha256=$X64_SHA256" >> $GITHUB_OUTPUT

      - name: Update cask file
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          sed -i "s/version \".*\"/version \"${{ steps.version_check.outputs.new_version }}\"/" Casks/{name}.rb
          sed -i '/on_arm do/,/end/{s/sha256 ".*"/sha256 "${{ steps.checksums.outputs.arm64_sha256 }}"/}' Casks/{name}.rb
          sed -i '/on_intel do/,/end/{s/sha256 ".*"/sha256 "${{ steps.checksums.outputs.x64_sha256 }}"/}' Casks/{name}.rb

      - name: Commit and push changes
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add Casks/{name}.rb
          git commit -m "chore: update {AppName} to version ${{ steps.version_check.outputs.new_version }}"
          git push
```

---

## 工作流程

### Phase 1: 信息收集

**输入**: 用户请求（创建/更新 Cask 或 Formula）
**输出**: 上游仓库信息确认清单

#### Step 1.1: 确认上游仓库信息

**⚠️ 检查点**: 在创建之前，必须确认以下信息：

| 必需信息 | 说明 | 用户确认方式 |
|---------|------|-------------|
| GitHub owner/repo | 上游仓库地址 | 用户提供或从 URL 提取 |
| 发布文件格式 | dmg、zip、tar.gz 等 | 分析 GitHub Releases |
| 架构支持 | arm64/x64 或 universal | 分析发布文件命名 |
| 应用名称 | 用于 cask/formula 名称 | 用户确认 |

```
询问用户：
「请确认以下信息：
- GitHub 仓库: {owner}/{repo}
- 发布文件格式: {format}
- 架构支持: {archs}
- Cask/Formula 名称: {name}

是否正确？」
```

#### Step 1.2: 分析发布文件命名规则

从 GitHub Releases 分析文件命名：
- `App-{version}-mac-arm64.dmg` → arm64 架构
- `App-{version}-mac-x64.dmg` → x64 架构
- `App-{version}_universal.dmg` → Universal（单文件）

---

### Phase 2: 文件生成

**输入**: Phase 1 确认的信息
**输出**: Cask/Formula 文件 + GitHub Workflow

#### Step 2.1: 生成 Cask 或 Formula

根据架构支持选择模板：
- **双架构**: 使用 `on_arm do` / `on_intel do`
- **单架构**: 直接 sha256 + url
- **Universal**: 单文件，无架构区分

**⚠️ 检查点**: sha256 使用 `PLACEHOLDER` 占位符，确认用户理解：

```
询问用户：
「Cask/Formula 中的 sha256 使用 PLACEHOLDER 占位符，
GitHub Actions workflow 运行时会自动下载文件并计算真实 sha256。
是否继续？」
```

#### Step 2.2: 生成 GitHub Workflow

生成自动更新 workflow，包含：
- `workflow_dispatch`: 手动触发 + 版本输入
- `schedule`: 定时检查（推荐每12小时）
- checksum 自动计算步骤

---

### Phase 3: 验证与发布

**输入**: Phase 2 生成的文件
**输出**: 验证结果 + 发布到 GitHub

#### Step 3.1: 本地验证（可选）

```bash
# 验证 Cask
brew audit --cask {name}
brew style --cask {name}

# 验证 Formula
brew audit {formula}
```

**⚠️ 检查点**: 验证失败时询问用户：

```
如果 brew audit 报错：
「验证发现问题：{error}
是否继续提交，或先修复问题？」
```

#### Step 3.2: 提交到仓库

```bash
git add Casks/{name}.rb Formula/{name}.rb .github/workflows/update-{name}-version.yml
git commit -m "feat: add {name} Homebrew Cask/Formula with auto-update workflow"
git push
```

---

## 边界条件与错误处理

| 异常情况 | 处理方式 | Fallback |
|---------|---------|---------|
| GitHub API 不可达 | 提示用户手动输入版本 | 使用用户指定版本 |
| 发布文件不存在 | 检查文件命名规则 | 询问用户确认 URL 格式 |
| sha256 计算失败 | 文件下载失败 | 检查 curl 错误并提示 |
| brew audit 报错 | 显示具体错误 | 用户选择修复或跳过 |
| 版本格式不规范 | 处理 v 前缀等 | `sed 's/^v//'` |
| 多架构文件缺失 | 只有单架构 | 询问用户是否降级为单架构 |

---

## 决策速查表

| 场景 | 决策 |
|------|------|
| 用户未提供架构信息 | **询问**: 「该应用支持哪些架构？arm64/x64/universal？」 |
| 用户未提供文件格式 | **分析**: 从 GitHub Releases 页面获取文件列表 |
| sha256 是否预填 | **使用 PLACEHOLDER**: workflow 自动计算 |
| 是否需要 livecheck | **推荐添加**: 自动版本检测 |
| 定时更新频率 | **推荐**: 每12小时 (`0 */12 * * *`) |

---

## 常用命令

### 本地验证

```bash
# 验证 Cask
brew audit --cask {name}
brew style --cask {name}

# 验证 Formula
brew audit {formula}
brew style {formula}

# 本地安装测试
brew install --cask {name}
brew install {formula}
```

### 版本检测

```bash
# 获取最新版本
curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r '.tag_name' | sed 's/^v//'

# 检查版本格式
echo "v1.2.3" | sed 's/^v//'  # 输出: 1.2.3
```

---

## 最佳实践

### ✅ 推荐做法

1. **使用 livecheck**: 配置自动版本检测
2. **多架构支持**: 为 arm64 和 x64 分别提供 sha256
3. **定时更新**: 设置 schedule 自动检查版本
4. **手动触发**: 提供 workflow_dispatch 支持手动指定版本
5. **校验和验证**: 确保下载文件大小合理后再计算 sha256

### ❌ 避免的做法

1. **硬编码版本**: 不使用 livecheck
2. **单架构支持**: 只支持 Intel Mac
3. **跳过验证**: 不运行 brew audit
4. **忽略错误**: curl 失败不检查
5. **手动 sha256**: 不自动计算校验和

---

## 触发场景

使用此技能的场景:

- 「帮我更新 Homebrew Tap 中的 xxx 版本」
- 「创建一个新的 Homebrew Cask」
- 「添加一个 Homebrew Formula」
- 「发布 xxx 到我的 Homebrew Tap」
- 「更新 xxx 的 sha256 校验和」
- 「为 xxx 创建自动更新 workflow」

---

## 输入要求

创建/更新 Cask 或 Formula 时，请提供:

1. **上游仓库信息**: GitHub owner/repo
2. **应用名称**: 用于 cask/formula 名称
3. **发布文件格式**: dmg、zip、tar.gz 等
4. **架构支持**: 是否需要多架构
5. **版本号**: 手动指定或自动检测

---

## 输出格式

技能将生成:

1. **Cask/Formula 文件**: `.rb` 文件
2. **GitHub Workflow**: `.github/workflows/update-xxx-version.yml`
3. **更新说明**: commit message 格式
4. **验证结果**: brew audit 输出

详见各 reference 文档获取完整模板和示例。