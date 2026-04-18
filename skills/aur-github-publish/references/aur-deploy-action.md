# AUR 部署 Action 配置

## KSXGitHub/github-actions-deploy-aur

### 基本用法

```yaml
- name: Publish to AUR
  uses: KSXGitHub/github-actions-deploy-aur@v4.1.3
  with:
    pkgname: myapp-bin
    pkgbuild: ./myapp-bin/PKGBUILD
    commit_username: ${{ secrets.AUR_USERNAME }}
    commit_email: ${{ secrets.AUR_EMAIL }}
    ssh_private_key: ${{ secrets.AUR_SSH_PRIVATE_KEY }}
    commit_message: "Update to version 1.0.0"
```

### 完整参数

```yaml
- name: Publish to AUR
  uses: KSXGitHub/github-actions-deploy-aur@v4.1.3
  with:
    # 必需参数
    pkgname: myapp-bin              # AUR 包名
    pkgbuild: ./myapp-bin/PKGBUILD  # PKGBUILD 文件路径
    commit_username: ${{ secrets.AUR_USERNAME }}
    commit_email: ${{ secrets.AUR_EMAIL }}
    ssh_private_key: ${{ secrets.AUR_SSH_PRIVATE_KEY }}
    commit_message: "Update to version 1.0.0"

    # 推荐参数
    updpkgsums: true                # 自动计算 checksum ⭐
    ssh_keyscan_types: rsa,ecdsa,ed25519

    # 可选参数
    assets: |                       # 附加文件
      ./myapp-bin/myapp-bin.install
      ./myapp-bin/myapp.conf
    post_process: bash /github/workspace/.github/scripts/prune-aur-workdir.sh .
```

## 参数详解

### pkgname

AUR 包名，必须已存在于 AUR 或首次创建。

```yaml
pkgname: myapp-bin
pkgname: myapp-git
pkgname: myapp
```

### pkgbuild

PKGBUILD 文件的路径。

```yaml
pkgbuild: ./myapp-bin/PKGBUILD
pkgbuild: myapp-bin/PKGBUILD
```

### updpkgsums

**⭐ 推荐启用**

自动下载 source 文件并计算 checksum，更新 PKGBUILD 中的 sha256sums/md5sums。

```yaml
updpkgsums: true  # ✅ 启用自动 checksum
updpkgsums: false # ❌ 手动填写 checksum
```

**工作原理**:
1. 解析 PKGBUILD 的 source 字段
2. 下载所有 source 文件
3. 使用 `updpkgsums` 命令计算 checksum
4. 更新 PKGBUILD 中的 checksum 字段

### assets

包含额外需要上传到 AUR 的文件。

```yaml
# 单个文件
assets: ./myapp-bin/myapp-bin.install

# 多个文件
assets: |
  ./myapp-bin/myapp-bin.install
  ./myapp-bin/config.patch
  ./myapp-bin/myapp.service
```

### post_process

发布后清理脚本，用于删除不需要的文件。

```yaml
post_process: bash /github/workspace/.github/scripts/prune-aur-workdir.sh .
```

### ssh_keyscan_types

SSH 密钥类型，确保能连接到 AUR。

```yaml
ssh_keyscan_types: rsa,ecdsa,ed25519  # 推荐
ssh_keyscan_types: ed25519             # 最小
```

## SSH 密钥配置

### 生成密钥

```bash
# 使用 ed25519（推荐）
ssh-keygen -f aur_key -t ed25519 -C "your@email.com"

# 或使用 RSA
ssh-keygen -f aur_key -t rsa -b 4096 -C "your@email.com"
```

### 上传到 AUR

1. 登录 https://aur.archlinux.org/account/
2. 在 "SSH Public Key" 字段粘贴公钥内容

```bash
cat aur_key.pub
# 复制输出内容到 AUR
```

### 配置 GitHub Secrets

将私钥完整内容（包括 BEGIN/END 行）添加到 GitHub Secrets:

```bash
cat aur_key
# 输出格式:
# -----BEGIN OPENSSH PRIVATE KEY-----
# b3BlbnNzaC1rZXktdjEAAAA...
# -----END OPENSSH PRIVATE KEY-----
```

在 GitHub 仓库:
1. Settings → Secrets and variables → Actions
2. New repository secret
3. Name: `AUR_SSH_PRIVATE_KEY`
4. Value: 粘贴私钥完整内容

## 验证 SSH 连接

```bash
# 测试 SSH 连接
ssh -i aur_key aur@aur.archlinux.org help

# 成功输出:
# Usage: aur.git ...
```

## 常见问题

### 1. SSH 认证失败

**原因**: 私钥格式错误或未上传公钥
**解决**:
- 检查私钥格式是否完整（包括 BEGIN/END）
- 确认公钥已上传到 AUR
- 测试 SSH 连接

### 2. updpkgsums 失败

**原因**: source 文件下载失败
**解决**:
- 检查 source URL 是否正确
- 确认文件存在
- 检查网络连接

### 3. 文件未上传

**原因**: assets 参数配置错误
**解决**:
- 检查文件路径是否正确
- 使用 `post_process` 清理多余文件

## 首次创建 AUR 包

**⚠️ 重要: GitHub Actions workflow 只能推送修改，不能创建新仓库！**

首次发布新包时，必须先手动克隆并初始化 AUR 仓库：

### 步骤 1: 克隆空的 AUR 仓库

```bash
# 克隆（会创建一个新的空仓库）
git clone ssh://aur.archlinux.org/myapp-bin.git /tmp/myapp-bin
cd /tmp/myapp-bin
```

### 步骤 2: 创建基本文件

```bash
# 复制或创建 PKGBUILD
cp ~/your-project/myapp-bin/PKGBUILD .

# 如果有 .install 文件
cp ~/your-project/myapp-bin/myapp-bin.install .
```

### 步骤 3: 生成 .SRCINFO

```bash
# 生成源信息文件
makepkg --printsrcinfo > .SRCINFO
```

### 步骤 4: 配置并推送

```bash
# 配置 git 用户信息
git config user.name "your-aur-username"
git config user.email "your@email.com"

# 提交
git add PKGBUILD .SRCINFO *.install
git commit -m "Initial commit: myapp-bin v1.0.0"

# 推送（首次推送创建仓库）
git push origin master
```

### 步骤 5: 配置 GitHub Actions

仓库创建后，才能配置 GitHub Actions workflow 进行自动更新：

```yaml
- name: Publish to AUR
  uses: KSXGitHub/github-actions-deploy-aur@v4.1.3
  with:
    pkgname: myapp-bin  # ✅ 必须已存在于 AUR
    pkgbuild: ./myapp-bin/PKGBUILD
    # ...
```

**注意**: workflow 只能推送修改，首次发布必须手动完成以上步骤。

### SSH 连接测试

推送前测试 SSH 连接：

```bash
# 测试 SSH 认证
ssh -i ~/.ssh/aur_key aur@aur.archlinux.org help

# 成功输出:
# Usage: aur.git-upload-pack 'repository'
# ...
```

## 参考链接

- [KSXGitHub/github-actions-deploy-aur](https://github.com/KSXGitHub/github-actions-deploy-aur)
- [AUR SSH 认证](https://wiki.archlinux.org/title/AUR#SSH_authentication)
- [AUR 提交指南](https://wiki.archlinux.org/title/AUR_submission_guidelines)