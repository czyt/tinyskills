# 最佳实践与常见问题

## ✅ 推荐做法

### 1. 首次发布前手动创建 AUR 仓库

**⚠️ GitHub Actions 无法创建新仓库，首次必须手动操作**

```bash
# 克隆空的 AUR 仓库
git clone ssh://aur.archlinux.org/myapp-bin.git /tmp/myapp-bin
cd /tmp/myapp-bin

# 添加 PKGBUILD
cp ~/your-project/PKGBUILD .

# 生成 .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# 推送
git add PKGBUILD .SRCINFO
git commit -m "Initial commit"
git push origin master
```

### 2. 使用 `-bin` 后缀

预编译包使用 `{name}-bin` 格式:

```bash
pkgname=myapp-bin  # ✅ 正确
pkgname=myapp      # ❌ 错误（源码包使用）
```

### 2. 使用 `updpkgsums: true`

让 workflow 自动计算 checksum:

```yaml
- name: Publish to AUR
  uses: KSXGitHub/github-actions-deploy-aur@v4.1.3
  with:
    updpkgsums: true  # ✅ 推荐
```

### 3. checksum 使用 SKIP

PKGBUILD 中使用 'SKIP' 占位符:

```bash
sha256sums=('SKIP')  # ✅ workflow 自动更新
sha256sums=('abc...') # ❌ 手动计算容易出错
```

### 4. 提供 provides/conflicts

声明与其他包的关系:

```bash
provides=('myapp')
conflicts=('myapp' 'myapp-git')
```

### 5. 定时自动更新

设置 schedule 自动检查版本:

```yaml
on:
  schedule:
    - cron: "0 */12 * * *"  # 每12小时
```

### 6. 支持 force 更新

允许同版本 bump pkgrel:

```yaml
inputs:
  force:
    description: "Force update (bump pkgrel)"
    default: false
    type: boolean
```

### 7. 使用 post_process 清理

清理不需要的文件:

```yaml
post_process: bash /github/workspace/.github/scripts/prune-aur-workdir.sh .
```

### 8. 本地验证

提交前运行 namcap:

```bash
namcap PKGBUILD
makepkg -sf
```

---

## ❌ 避免的做法

### 1. 硬编码 checksum

❌ 手动计算并硬编码:
```bash
sha256sums=('abc123...')
```

✅ 使用 SKIP:
```bash
sha256sums=('SKIP')
```

### 2. 缺少依赖声明

❌ 不声明依赖:
```bash
depends=()  # 空
```

✅ 声明必要依赖:
```bash
depends=('gtk3' 'libnotify' 'nss')
```

### 3. 跳过验证

❌ 不运行 namcap:
```bash
# 直接提交
git push
```

✅ 先验证:
```bash
namcap PKGBUILD
makepkg -sf
git push
```

### 4. pkgrel 不管理

❌ 版本更新 pkgrel 不重置:
```bash
pkgver=1.1.0
pkgrel=2  # ❌ 应该是 1
```

✅ 新版本重置 pkgrel:
```bash
pkgver=1.1.0
pkgrel=1  # ✅ 正确
```

### 5. 不更新 .SRCINFO

❌ 只更新 PKGBUILD:
```bash
sed -i "s/^pkgver=.*/pkgver=$NEW_VERSION/" PKGBUILD
git push  # ❌ .SRCINFO 未更新
```

✅ workflow 自动更新:
```yaml
updpkgsums: true  # 自动生成 .SRCINFO
```

---

## 常见问题

### 1. checksum 不匹配

**原因**: source URL 错误或文件不存在
**解决**:
- 检查 source URL 格式
- 确认文件可下载
- 使用 `updpkgsums: true`

### 2. SSH 认证失败

**原因**: 私钥格式错误或公钥未上传
**解决**:
- 检查私钥格式（包含 BEGIN/END）
- 确认公钥已上传到 AUR
- 测试 SSH 连接: `ssh -i key aur@aur.archlinux.org help`

### 3. 包名冲突

**原因**: AUR 已存在同名包
**解决**:
- 搜索 AUR: https://aur.archlinux.org/packages/
- 使用不同的包名或 `-bin` 后缀

### 4. 版本检测失败

**原因**: GitHub API 返回格式变化
**解决**:
- 检查 jq 解析语法
- 处理不同的 tag_name 格式

```bash
# 处理 v 前缀
VERSION=$(curl -s https://api.github.com/repos/user/repo/releases/latest | jq -r '.tag_name' | sed 's/^v//')

# 处理不同格式
VERSION=$(curl -s https://api.github.com/repos/user/repo/releases/latest | jq -r '.tag_name' | sed 's/^v//' | sed 's/^release-//')
```

### 5. 依赖缺失

**原因**: depends 未正确声明
**解决**:
- 运行 `namcap PKGBUILD` 检查
- 查看应用文档确认依赖

### 6. 权限问题

**原因**: deb 包解压后权限不正确
**解决**:
```bash
chmod -R u=rwX,go=rX "${pkgdir}"
```

---

## Workflow 调试

### 本地测试 workflow

```bash
# 使用 act (GitHub Actions 本地运行器)
act -j update-pkgbuild

# 或手动执行 steps
cd {pkgname}
CURRENT=$(grep '^pkgver=' PKGBUILD | cut -d'=' -f2)
NEW_VERSION=$(curl -s https://api.github.com/repos/user/repo/releases/latest | jq -r '.tag_name' | sed 's/^v//')
sed -i "s/^pkgver=.*/pkgver=$NEW_VERSION/" PKGBUILD
sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
```

### 查看 workflow 日志

GitHub Actions 日志会显示:
- 版本检测结果
- 更新步骤
- AUR 发布结果

---

## 参考链接

- [AUR 提交指南](https://wiki.archlinux.org/title/AUR_submission_guidelines)
- [PKGBUILD 最佳实践](https://wiki.archlinux.org/title/Creating_packages)
- [namcap 使用](https://wiki.archlinux.org/title/Namcap)