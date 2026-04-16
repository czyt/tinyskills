# 首次发布引导

## 概述

首次发布新 Cask 或 Formula 时，传统的流程需要手动创建文件、验证、提交。本指南提供一种更简便的方式：**通过版本号差异触发首次发布**。

核心思路：
- 设置一个低于最新版本的初始版本号（patch version 回退）
- GitHub Action 运行时会检测到版本变化，自动完成首次发布
- checksum 由 workflow 自动计算

---

## 首次发布检测流程

### Step 1: 检查包状态

**判断是否首次发布**：

```bash
# 检查 Homebrew Tap 中是否存在该 Cask/Formula
# 在 Tap 仓库中检查文件
ls Casks/{name}.rb Formula/{name}.rb

# 或使用 git 检查
git ls-files Casks/{name}.rb Formula/{name}.rb
```

| 状态 | 判断 |
|------|------|
| 文件不存在 | 首次发布 |
| 文件已存在 | 正常更新流程 |

### Step 2: 引导用户选择

**⚠️ 关键检查点**：首次发布时必须询问用户

```
询问用户：
「检测到该 Cask/Formula 尚未在 Homebrew Tap 发布，属于首次发布。

有两种方式完成首次发布：

【方案 A】GitHub 自动发布（推荐）
- 设置初始版本号为最新版本减一
- GitHub Action 检测版本变化后自动发布
- checksum 由 workflow 自动计算
- 简单快捷，无需手动操作

【方案 B】传统手动发布
- 手动创建 Cask/Formula 文件
- 手动运行 brew audit 验证
- 手动提交推送
- 需要熟悉 Homebrew 规范

是否选择 GitHub 自动发布？」
```

---

## GitHub 自动发布策略

### Step 3: 确定初始版本号

**算法**：patch version 回退一个版本

```bash
# 获取上游最新版本
LATEST_VERSION=$(curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r '.tag_name' | sed 's/^v//')

# 计算 patch version 回退（假设版本格式为 X.Y.Z）
# 示例：1.2.5 → 1.2.4
INITIAL_VERSION=$(echo "$LATEST_VERSION" | awk -F. '{print $1"."$2"."$3-1}')

# 如果版本号格式特殊，需要更灵活的处理
# 示例：2024.01.15 → 2024.01.14
INITIAL_VERSION=$(echo "$LATEST_VERSION" | awk -F. '{for(i=1;i<NF;i++) printf "%s.", $i; print $NF-1}')
```

**版本回退策略表**：

| 版本格式 | 最新版本 | 初始版本 | 说明 |
|---------|---------|---------|------|
| X.Y.Z | 1.2.5 | 1.2.4 | 标准语义版本 |
| X.Y.Z-pre | 1.2.5-beta | 1.2.4 | 预发布版本（去掉后缀） |
| YYYY.MM.DD | 2024.01.15 | 2024.01.14 | 日期格式 |
| vX.Y.Z | v1.2.5 | 1.2.4 | 带 v 前缀 |
| 单数字 | 5 | 4 | 单数字版本 |

### Step 4: 处理无法获取版本号的情况

**如果上游无 releases 或 API 不可达**：

```
询问用户：
「无法自动获取上游版本号。

请手动输入初始版本号：
- 如果知道最新版本：输入最新版本减一
- 如果不确定：输入一个明显低于预期的版本（如 0.0.1）

初始版本号：」
```

**初始版本号原则**：
- 必须低于真实最新版本（触发 workflow 更新）
- checksum 使用 PLACEHOLDER（workflow 自动计算）
- 作为触发器，workflow 会发布真正的最新版本

### Step 5: 生成初始 Cask/Formula

**使用初始版本号生成文件**：

#### Cask 示例

```ruby
cask "{name}" do
  version "{initial_version}"  # ⚠️ 使用初始版本（低于最新）
  
  on_arm do
    sha256 "PLACEHOLDER"  # workflow 会自动计算
    url "https://github.com/{owner}/{repo}/releases/download/v#{version}/{file}-#{version}-mac-arm64.dmg"
  end
  
  on_intel do
    sha256 "PLACEHOLDER"  # workflow 会自动计算
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

#### Formula 示例

```ruby
class {ClassName} < Formula
  desc "{description}"
  homepage "{homepage}"
  version "{initial_version}"  # ⚠️ 使用初始版本（低于最新）
  license "{license}"
  
  on_macos do
    if Hardware::CPU.arm?
      url "{arm64_url}"
      sha256 "PLACEHOLDER"  # workflow 会自动计算
      
      def install
        bin.install "{binary}" => "{name}"
      end
    end
    
    if Hardware::CPU.intel?
      url "{x64_url}"
      sha256 "PLACEHOLDER"  # workflow 会自动计算
      
      def install
        bin.install "{binary}" => "{name}"
      end
    end
  end
  
  test do
    system "#{bin}/{name}", "--version"
  end
end
```

**注意**：
- sha256 使用 `PLACEHOLDER`，workflow 会自动计算真实 checksum
- URL 中的版本号使用初始版本（workflow 会更新）

---

## Workflow 首次触发

### Step 6: 提交到 GitHub

```bash
# 添加文件到 GitHub 仓库
git add Casks/{name}.rb .github/workflows/update-{name}-version.yml
git commit -m "feat: add {name} Homebrew Cask initial setup (version {initial_version})"
git push
```

### Step 7: 手动触发 Workflow

**触发方式**：

```bash
# 方式 1: GitHub CLI
gh workflow run update-{name}-version.yml

# 方式 2: GitHub 网页
# Actions → Update {AppName} Version → Run workflow

# 方式 3: 等待定时触发
# schedule 会自动检测版本变化
```

### Step 8: Workflow 首次发布流程

**Workflow 执行逻辑**：

```yaml
- name: Get latest version
  run: |
    # 当前版本: 1.2.4 (初始版本)
    # 最新版本: 1.2.5
    # 版本不同 → 触发更新

- name: Download files and calculate checksums
  run: |
    # 下载最新版本文件（1.2.5）
    # 计算真实 sha256

- name: Update cask/formula file
  run: |
    # 更新 version: 1.2.4 → 1.2.5
    # 更新 sha256: PLACEHOLDER → 真实 checksum
    # 更新 URL 中的版本号

- name: Commit and push changes
  run: |
    git commit -m "chore: update {AppName} to version 1.2.5"
    git push
```

**首次发布成功标志**：
- Workflow 检测到版本变化
- 自动更新到最新版本
- 计算真实 checksum
- 提交更新后的文件

---

## 完整首次发布流程图

```
首次发布检测
    │
    ├─→ 已存在？ → 进入正常更新流程
    │
    └─→ 不存在？
         │
         ├─→ 引导用户选择发布方式
         │    │
         │    ├─→ 方案 A: GitHub 自动发布
         │    │    │
         │    │    ├─→ 获取最新版本号
         │    │    │    ├─→ 成功 → 计算初始版本 (patch -1)
         │    │    │    └─→ 失败 → 用户手动输入
         │    │    │
         │    │    ├─→ 确认软件类型
         │    │    │    ├─→ GUI 应用 → Cask (Casks/)
         │    │    │    ├─→ CLI 工具 → Formula (Formula/)
         │    │    │    └─→ 字体 → Cask Font (font-{name}.rb)
         │    │    │
         │    │    ├─→ 确认架构支持
         │    │    │    ├─→ arm64 + x64 → 双架构模板
         │    │    │    ├─→ 仅 arm64 → 单架构
         │    │    │    └─→ universal → 单文件
         │    │    │
         │    │    ├─→ 生成初始 Cask/Formula
         │    │    ├─→ 提交到 GitHub
         │    │    ├─→ 用户触发 workflow
         │    │    └─→ Workflow 自动更新发布
         │    │
         │    └─→ 方案 B: 传统手动发布
         │         ├─→ 创建 Cask/Formula
         │         ├─→ 手动验证 (brew audit)
         │         ├─→ 手动提交推送
         │         └─→ 后续使用 workflow 更新
```

---

## 与传统方式对比

| 特性 | GitHub 自动发布 | 传统手动发布 |
|------|----------------|-------------|
| **难度** | 低（自动触发） | 中（需熟悉 Homebrew） |
| **步骤** | 3 步 | 5+ 步 |
| **checksum** | 自动计算 | 手动计算或占位符 |
| **验证** | 可选（workflow 后验证） | 必须（brew audit） |
| **首次发布** | Workflow 完成 | 手动完成 |
| **后续更新** | 自动 | 自动 |
| **适用场景** | 大多数用户 | 熟悉 Homebrew 的用户 |

---

## 边界情况处理

### 情况 1: 最新版本为 0.0.1

```bash
# 最新版本: 0.0.1
# 初始版本: 0.0.0（无效）
# 解决方案: 使用 0.0.0-1 或询问用户
```

```
询问用户：
「最新版本为 0.0.1，无法回退。

建议：
- 使用 0.0.0 作为初始版本（workflow 会发布 0.0.1）
- 或选择传统手动发布

是否使用 0.0.0 作为初始版本？」
```

### 情况 2: 版本号格式非标准

```bash
# 示例: release-2024, build-100
# 处理: 尝试解析数字部分回退
```

```
询问用户：
「检测到非标准版本格式: {version}

请手动输入初始版本号（低于该版本）：」
```

### 情况 3: 上游无任何发布

```
询问用户：
「上游仓库无任何 release 或 tag。

建议：
- 使用版本号 0.0.0 作为初始版本
- 等待上游发布后 workflow 自动更新

是否使用 0.0.0？」
```

### 情况 4: 字体包首次发布

**⚠️ 字体包特殊规则**：

```
询问用户：
「检测到这是一个字体包。字体包有特殊要求：

1. 命名必须以 font- 开头: font-{name}.rb
2. 建议放在独立的 homebrew-fonts Tap
3. 使用 font 指令而非 app

确认命名格式：font-{name}.rb
是否继续？」
```

---

## 软件类型确认表

首次发布时必须确认软件类型：

| 类型特征 | 目录 | 安装位置 | sha256 计算 |
|---------|------|---------|------------|
| GUI 应用 (.dmg/.pkg/.zip) | Casks/ | /Applications | 双架构或单架构 |
| CLI 工具（二进制） | Formula/ | /opt/homebrew/bin | 双架构或单架构 |
| 字体 (.ttf/.otf) | Casks/ | ~/Library/Fonts | 单文件 |

**类型判断决策表**：

| 上游发布文件格式 | 推荐类型 | 目录 |
|----------------|---------|------|
| `.dmg` / `.pkg` | Cask (App) | Casks/ |
| `.zip` (含 .app) | Cask (App) | Casks/ |
| `.ttf` / `.otf` | Cask (Font) | Casks/ |
| 二进制可执行文件 | Formula | Formula/ |
| tar.gz / zip (仅二进制) | Formula | Formula/ |

---

## 示例对话

### 场景: 用户首次发布一个 GUI 应用 Cask

```
助手: 检测到 myapp 尚未在 Homebrew Tap 发布，属于首次发布。

有两种方式完成首次发布：

【方案 A】GitHub 自动发布（推荐）
- 自动获取最新版本，设置初始版本号
- checksum 由 workflow 自动计算
- Workflow 触发后自动更新发布
- 简单快捷

【方案 B】传统手动发布
- 手动创建 Cask 文件
- 手动计算 checksum
- 手动验证和提交

是否选择 GitHub 自动发布？

用户: 是的，选择自动发布

助手: 正在获取上游最新版本...
- 上游仓库: owner/myapp
- 最新版本: 2.1.3
- 初始版本: 2.1.2 (patch 回退)

请确认软件类型：
- GUI 桌面应用 → Cask (Casks/ 目录)
- CLI 命令行工具 → Formula (Formula/ 目录)
- 字体文件 → Cask Font (font-{name}.rb)

该软件属于哪种类型？

用户: GUI 应用

助手: 请确认架构支持：
- arm64 + x64 → 双架构模板
- 仅 arm64 → 单架构
- universal → 单文件

支持哪些架构？

用户: 双架构 arm64 + x64

助手: 将生成以下文件：
- Casks/myapp.rb (version: 2.1.2, sha256: PLACEHOLDER)
- .github/workflows/update-myapp-version.yml

后续操作：
1. 提交到 GitHub 仓库
2. 手动触发 workflow 或等待定时触发
3. Workflow 自动更新到 myapp 2.1.3 并计算 checksum

是否继续生成文件？
```

---

## 参考链接

- [Homebrew Cask 文档](https://docs.brew.sh/Cask-Cookbook)
- [Homebrew Formula 文档](https://docs.brew.sh/Formula-Cookbook)
- [Homebrew Tap 维护指南](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)