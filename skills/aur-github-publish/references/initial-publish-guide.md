# 首次发布引导

## 概述

首次发布新包时，传统的流程需要手动克隆 AUR 仓库、创建文件、提交推送。本指南提供一种更简便的方式：**通过版本号差异触发首次发布**。

核心思路：
- 设置一个低于最新版本的初始版本号（patch version 回退）
- GitHub Action 运行时会检测到版本变化，自动完成首次发布

---

## 首次发布检测流程

### Step 1: 检查包状态

**判断是否首次发布**：

```bash
# 检查 AUR 中是否存在该包
curl -s "https://aur.archlinux.org/packages/{pkgname}" -o /dev/null -w "%{http_code}"
# 200 = 已存在
# 404 = 不存在（首次发布）

# 或者使用 RPC API
curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg={pkgname}" | jq -r '.resultcount'
# 0 = 不存在
# 1+ = 已存在
```

### Step 2: 引导用户选择

**⚠️ 关键检查点**：首次发布时必须询问用户

```
询问用户：
「检测到该包尚未在 AUR 发布，属于首次发布。

有两种方式完成首次发布：

【方案 A】GitHub 自动发布（推荐）
- 设置初始版本号为最新版本减一
- GitHub Action 检测版本变化后自动发布
- 简单快捷，无需手动操作 AUR

【方案 B】传统手动发布
- 手动克隆 AUR 仓库
- 创建 PKGBUILD 和 .SRCINFO
- 手动推送创建仓库
- 需要熟悉 AUR 操作

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
- 可以不存在（不需要真实下载）
- 作为触发器，workflow 会发布真正的最新版本

### Step 5: 生成初始 PKGBUILD

**使用初始版本号生成 PKGBUILD**：

```bash
pkgname={pkgname}
pkgver={initial_version}  # ⚠️ 使用初始版本（低于最新）
pkgrel=1
# ... 其他配置
sha256sums=('SKIP')  # workflow 会自动计算
```

**注意**：
- checksum 使用 `SKIP`，首次发布时 workflow 会计算真实 checksum
- source URL 使用初始版本号（如果文件不存在，workflow 会更新 URL）

---

## Workflow 首次触发

### Step 6: 提交到 GitHub

```bash
# 添加文件到 GitHub 仓库
git add {pkgname}/PKGBUILD .github/workflows/update-{pkgname}.yml
git commit -m "feat: add {pkgname} initial setup (version {initial_version})"
git push
```

### Step 7: 手动触发 Workflow

**触发方式**：

```bash
# 方式 1: GitHub CLI
gh workflow run update-{pkgname}.yml

# 方式 2: GitHub 网页
# Actions → Update {pkgname} Version → Run workflow

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

- name: Update PKGBUILD
  run: |
    # 更新 pkgver: 1.2.4 → 1.2.5
    # 更新 pkgrel: 1

- name: Publish to AUR
  uses: KSXGitHub/github-actions-deploy-aur@v4.1.2
  with:
    updpkgsums: true  # ✅ 自动计算真实 checksum
    # ... 其他参数
```

**首次发布成功标志**：
- Workflow 检测到版本变化
- 自动更新 PKGBUILD 到最新版本
- 计算真实 checksum
- 推送到 AUR 创建仓库

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
         │    │    ├─→ 生成初始 PKGBUILD
         │    │    ├─→ 提交到 GitHub
         │    │    ├─→ 用户触发 workflow
         │    │    └─→ Workflow 自动发布到 AUR
         │    │
         │    └─→ 方案 B: 传统手动发布
         │         ├─→ 克隆 AUR 仓库
         │         ├─→ 创建 PKGBUILD + .SRCINFO
         │         ├─→ 手动推送
         │         └─→ 后续使用 workflow 更新
```

---

## 与传统方式对比

| 特性 | GitHub 自动发布 | 传统手动发布 |
|------|----------------|-------------|
| **难度** | 低（自动触发） | 中（需熟悉 AUR） |
| **步骤** | 3 步 | 5+ 步 |
| **SSH 操作** | 无需手动 | 需要手动 SSH |
| **首次发布** | Workflow 完成 | 手动完成 |
| **后续更新** | 自动 | 自动 |
| **适用场景** | 大多数用户 | 熟悉 AUR 的用户 |

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

---

## Secrets 配置提醒

**⚠️ 首次发布前必须配置 Secrets**：

| Secret | 说明 | 配置位置 |
|--------|------|---------|
| `AUR_USERNAME` | AUR 用户名 | GitHub Settings → Secrets |
| `AUR_EMAIL` | AUR 邮箱 | GitHub Settings → Secrets |
| `AUR_SSH_PRIVATE_KEY` | AUR SSH 私钥 | GitHub Settings → Secrets |

**SSH 密钥必须提前上传到 AUR**：

```bash
# 生成密钥
ssh-keygen -f aur_key -t ed25519 -C "your@email.com"

# 上传公钥到 AUR
# https://aur.archlinux.org/account/

# 添加私钥到 GitHub Secrets
```

---

## 示例对话

### 场景: 用户首次发布 autocli-bin

```
助手: 检测到 autocli-bin 尚未在 AUR 发布，属于首次发布。

有两种方式完成首次发布：

【方案 A】GitHub 自动发布（推荐）
- 自动获取最新版本，设置初始版本号
- Workflow 触发后自动发布到 AUR
- 简单快捷，无需手动操作 AUR

【方案 B】传统手动发布
- 手动克隆 AUR 仓库并推送
- 需要熟悉 AUR 操作

是否选择 GitHub 自动发布？

用户: 是的，选择自动发布

助手: 正在获取上游最新版本...
- 上游仓库: nashsu/AutoCLI
- 最新版本: 1.2.5
- 初始版本: 1.2.4 (patch 回退)

将生成以下文件：
- autocli-bin/PKGBUILD (version: 1.2.4)
- .github/workflows/update-autocli-bin.yml

后续操作：
1. 提交到 GitHub 仓库
2. 手动触发 workflow 或等待定时触发
3. Workflow 自动发布 autocli-bin 1.2.5 到 AUR

是否继续生成文件？
```

---

## 参考链接

- [AUR 提交指南](https://wiki.archlinux.org/title/AUR_submission_guidelines)
- [KSXGitHub/github-actions-deploy-aur](https://github.com/KSXGitHub/github-actions-deploy-aur)