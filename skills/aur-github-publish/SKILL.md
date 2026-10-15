---
name: aur-github-publish
description: 创建、更新、验证并发布 AUR 包及 GitHub Actions 自动化。覆盖第三方版本监控、自有项目 tag 发布、GoReleaser、预编译多架构包、deb/rpm/tar.gz/AppImage，以及没有版本化 URL、只提供 mutable latest 下载地址的上游。用户提到首次发布 AUR、创建或更新 PKGBUILD、AUR 自动发布、pkgrel、checksum、updpkgsums、GoReleaser AUR、latest deb 自动检测时使用。
---

# AUR GitHub 发布助手

从上游发布事实生成可验证的 PKGBUILD 与自动发布 workflow。先识别版本契约，再决定检测策略；不要默认所有上游都有 GitHub Release 或版本化 URL。

## 资源路由

只读取当前任务需要的 reference，不要把所有模板一次载入：

| 任务 | 必读 reference |
|---|---|
| 首次创建 AUR 包 | [references/initial-publish-guide.md](references/initial-publish-guide.md)、[references/aur-deploy-action.md](references/aur-deploy-action.md) |
| GitHub Release 定时监控 | [references/workflow-template.md](references/workflow-template.md) |
| mutable `latest` URL / 包内版本 | [references/workflow-template.md](references/workflow-template.md) 的 “Mutable `latest` Debian 包” |
| PKGBUILD 语法与多架构模板 | [references/pkgbuild-template.md](references/pkgbuild-template.md) |
| deb/rpm/tar.gz/AppImage | [references/package-types.md](references/package-types.md) |
| GoReleaser | [references/goreleaser-aur.md](references/goreleaser-aur.md) |
| 排障与质量检查 | [references/best-practices.md](references/best-practices.md) |
| 需要已验证案例 | [references/real-world-examples.md](references/real-world-examples.md) |

## 输入与产物

### 最低输入

- 上游主页、仓库或下载 URL
- 期望的 AUR 包名
- 发布物格式与支持架构
- 运行时依赖；未知时从包元数据、二进制与 namcap 探测
- 发布权限范围：只生成文件，或提交、推送并触发 workflow

能从本地仓库、上游 API、发布文件或 AUR RPC 得到的信息直接检查，不重复询问。

### 标准产物

```text
{repo}/
├── {pkgname}/
│   ├── PKGBUILD
│   ├── *.install / launcher / patch   # 仅在构建需要时
│   └── upstream.env                   # 可选，仅 GitHub workflow 状态
└── .github/workflows/update-{pkgname}.yml
```

不要在 GitHub 包目录提交 `.SRCINFO`。deploy action 在 AUR 工作目录生成并提交它。

## Step 1：选择发布通道

| 条件 | 通道 | 版本来源 |
|---|---|---|
| 维护第三方稳定版本 | 定时监控 | Release API、下载清单、网页或包内元数据 |
| 自有项目 tag 后编译发布 | 编译发布一体化 | git tag |
| Go/Rust/Zig 已用 GoReleaser | GoReleaser | tag / GoReleaser 模板变量 |

如果用户已给出第三方下载 URL，直接选择定时监控；如果用户明确说 GoReleaser，直接选择 GoReleaser。只有两条通道都合理且会改变仓库结构时才询问。

## Step 2：确定包类型与命名

| 实际构建方式 | 默认命名 | 必要字段 |
|---|---|---|
| 安装上游预编译产物 | `{name}-bin` | `provides`、`conflicts` |
| 从稳定源码构建 | `{name}` | `build()` / `package()` |
| 从 VCS 最新提交构建 | `{name}-git` | `pkgver()`、VCS source |
| 字体 | `{name}-font` 或 `font-{name}` | 通常 `arch=('any')` |

🔴 **CHECKPOINT · 包名冲突**：如果用户指定的名字与构建方式不符，或 AUR 已有同名/同功能包，展示 AUR RPC 结果和建议名称，等待用户决定。用户已明确接受现有命名时不要重复阻塞。

检查 AUR：

```bash
curl -fsSL "https://aur.archlinux.org/rpc/?v=5&type=info&arg={pkgname}" | jq -er '.resultcount'
```

## Step 3：识别版本契约

按以下顺序选择第一个可靠来源：

1. GitHub/GitLab Release API 的 tag。
2. 上游 manifest、update JSON/XML 或版本化下载页面。
3. 发布文件内部元数据：deb control、rpm metadata、AppImage metadata、二进制 `--version`。
4. 只有内容变化信号而没有版本字段时，设计确定性的 Arch `pkgver` 映射并记录依据；不能静默拿日期或 ETag 冒充上游版本。

所有网络请求使用 fail-fast：

```bash
curl --fail --silent --show-error --location \
  --retry 3 --retry-all-errors --connect-timeout 15 --max-time 120 URL
```

对自动检测值执行非空、格式、资产存在和防降级检查。手动输入版本也必须验证对应资产或包内版本。

### Mutable `latest` URL 决策

当 URL 永远是 `latest/app_amd64.deb` 且内容原地替换时：

1. 用 ETag/Last-Modified 判断是否值得下载；它们只是缓存验证器。
2. ETag 缺失或变化时下载**所有架构**。
3. 从每个 deb 读取 `Version` 与 `Architecture`：

   ```bash
   dpkg-deb --field app_amd64.deb Version
   dpkg-deb --field app_amd64.deb Architecture
   ```

4. 两架构版本不同则失败并等待上游同步，不能发布混合版本。
5. 新版本更新 `pkgver` 并重置 `pkgrel=1`；内容变化但版本相同则 bump `pkgrel`。
6. 将上次**成功发布**的验证器保存在 `{pkgname}/upstream.env`，不要放进 PKGBUILD。
7. AUR 发布成功后才提交 PKGBUILD 与 `upstream.env`；失败时保留旧状态，下一次自动重试。

完整 workflow、无 `dpkg-deb` fallback 和失败分支见 [references/workflow-template.md](references/workflow-template.md)。

## Step 4：生成 PKGBUILD

遵守以下不变量：

- GitHub PKGBUILD 的 checksum 使用 `SKIP`；发布 action 必须设置 `updpkgsums: true`。
- 多架构 source 必须使用不同本地文件名，并包含 `${pkgver}` 防止 makepkg 复用 mutable URL 的旧缓存。
- `source_x86_64` 与 `source_aarch64` 分开；`package()` 按 `$CARCH` 选择文件。
- `provides` / `conflicts` 与实际可执行文件、已有包一致。
- 预编译包声明运行依赖；构建工具放入 `makedepends`。
- 预编译二进制包默认声明 `options=('!strip' '!debug')`：不重复 strip 上游已处理的二进制（Go/Rust 二进制可能被 strip 破坏），也不生成成倍增大体积的 debug 包。仅源码构建且确需符号分离时才调整。
- 本地 launcher、patch、service 等出现在 `source=()` 时，必须同时列入 deploy action 的 `assets`。

多架构 mutable deb 最小结构：

```bash
pkgname={pkgname}
pkgver={version}
pkgrel=1
arch=('x86_64' 'aarch64')

_deb_x86_64="app_${pkgver}_amd64.deb"
_deb_aarch64="app_${pkgver}_arm64.deb"
source_x86_64=("${_deb_x86_64}::https://example/latest/app_amd64.deb")
source_aarch64=("${_deb_aarch64}::https://example/latest/app_arm64.deb")
noextract=("${_deb_x86_64}" "${_deb_aarch64}")
options=('!strip' '!debug')
sha256sums_x86_64=('SKIP')
sha256sums_aarch64=('SKIP')

package() {
  local deb_var="_deb_${CARCH}"
  local deb="${!deb_var}"
  bsdtar -xOf "${srcdir}/${deb}" data.tar.xz |
    bsdtar --no-same-owner -xf - -C "${pkgdir}"
}
```

不要假定所有 deb 都使用同一种压缩格式。生成前用 `ar t package.deb` 检查成员；需要通用处理时动态选择 `data.tar.*`。

## Step 5：生成安全的 workflow

workflow 必须具备：

- `workflow_dispatch`：可选 `version` 与 `force`。
- `schedule`：第三方监控默认每 12 小时。
- `permissions: contents: write`。
- `concurrency`：同一包串行运行，`cancel-in-progress: false`。
- 网络和解析失败立即退出，禁止把 `null`、HTML 或空值写入 `pkgver`。
- 自动更新拒绝降级；显式人工降级必须单独授权。
- GitHub Actions 使用已核验版本，安全敏感 action 优先 pin 完整 commit SHA 并注明 tag。
- AUR deploy 在 GitHub 状态提交之前运行。

### Checksum 所有权

```yaml
sha256sums_x86_64=('SKIP') # GitHub PKGBUILD

- name: Publish to AUR
  uses: KSXGitHub/github-actions-deploy-aur@<verified-ref>
  with:
    updpkgsums: true         # AUR PKGBUILD 写入真实 checksum
```

不要把 deploy action 在临时 AUR 工作目录生成的 checksum 回写 GitHub，除非用户明确选择“GitHub 也保存固定 checksum”的另一种策略。

### Assets 包含与状态排除

`assets` 是精确包含列表；GitHub-only 状态不能进入 AUR：

```yaml
assets: ./{pkgname}/launcher.sh
post_process: >-
  bash /github/workspace/.github/scripts/prune-aur-workdir.sh . launcher.sh
  && test -f launcher.sh
  && test ! -e upstream.env
```

共享 prune 脚本应接受精确 basename 白名单。不要为了一个 launcher 放宽成保留全部 `*.sh`。

## Step 6：首次发布

先通过 AUR RPC 和 Git clone 区分三种状态：已发布、已初始化但空仓库、仓库不可访问。

🔴 **CHECKPOINT · 外部发布**：首次向 AUR 推送、设置 Secrets 或创建 SSH key 会改变外部状态。若用户只要求生成文件，停在发布说明；若用户已明确要求发布或已说明仓库初始化完成，继续执行。

必须具备：

- AUR 仓库可通过 `ssh://aur.archlinux.org/{pkgname}.git` 克隆；空仓库允许 deploy action 创建 root commit。
- GitHub Secrets：`AUR_USERNAME`、`AUR_EMAIL`、`AUR_SSH_PRIVATE_KEY`。
- SSH 公钥已上传 AUR。
- 不要求在 GitHub 仓库生成或提交 `.SRCINFO`。

不要使用“虚构的旧 pkgver”作为默认首次发布技巧。直接用真实版本，并通过 `force=true` 或显式首次发布条件运行 deploy；只有现有 workflow 必须依赖版本差异时才使用回退版本，并验证不会访问不存在的资产。

## Step 7：验证、提交与监控

### 本地验证

按环境可用性执行：

```bash
bash -n launcher.sh .github/scripts/*.sh
actionlint .github/workflows/update-{pkgname}.yml
(cd {pkgname} && makepkg --printsrcinfo)
namcap {pkgname}/PKGBUILD
git diff --check
```

构建大型包、安装包或推送前确认用户授权范围。用户要求提交时遵循仓库提交协议。

### 真实 workflow 验证

普通无变化运行只验证快速路径。至少再覆盖一次实际下载/版本解析路径：

```bash
gh workflow run update-{pkgname}.yml --ref <branch> -f force=true
gh run watch <run-id> --exit-status
```

对于 mutable URL，可用显式 `version=<当前真实版本>` 触发下载校验，同时避免伪造新版本。

发布后不要只相信绿色 action：

```bash
git clone https://aur.archlinux.org/{pkgname}.git /tmp/{pkgname}-verify
git -C /tmp/{pkgname}-verify log -1 --oneline
find /tmp/{pkgname}-verify -maxdepth 1 -type f -printf '%f\n' | sort
curl -fsSL "https://aur.archlinux.org/rpc/?v=5&type=info&arg={pkgname}"
```

核对 AUR Git：真实 checksum、`.SRCINFO`、PKGBUILD 和白名单 assets；不得出现 `upstream.env`、下载缓存或 API 响应。AUR Git 已更新但 RPC 暂时为 0 时等待索引同步，不要重复 bump `pkgrel`。

## 失败恢复表

| 触发条件 | 一线处理 | 仍失败兜底 |
|---|---|---|
| Release API 404/限流/空值 | 重试并校验 HTTP/JSON | 使用 manifest、网页或手动版本；验证资产后才写 PKGBUILD |
| ETag 缺失 | 下载并读取所有包元数据 | Last-Modified/Length 只作提示，不能代替包内版本 |
| 架构版本不同 | 立即失败，不提交状态 | 等上游同步，由下一次 schedule 重试 |
| deb control 无法读取 | 使用 `dpkg-deb --field` | 动态查找 `control.tar.*`；仍失败则停止 |
| `updpkgsums` 下载失败 | 检查 source、本地别名与 CDN | 不提交 ETag；修复后重跑 |
| AUR SSH/deploy 失败 | 检查 Secrets、公钥与仓库名 | 保留旧 GitHub 状态，修复后重试 |
| AUR 成功、GitHub 状态提交失败 | 从 AUR Git 读取真实 pkgver/pkgrel | 对齐 GitHub 后提交，不盲目 force 发布 |
| AUR RPC 暂未出现包 | 克隆 AUR Git 验证 commit | 等待索引，不重复发布 |
| workflow 并发冲突 | 添加按包名分组的 `concurrency` | 取消旧运行后基于远端最新 main 重跑 |

## 反例黑名单

- 不要用 `curl -s` 后直接把空值或 `null` 写入 `pkgver`。
- 不要从 mutable URL、ETag 或 Last-Modified 猜版本；读取上游声明或包内元数据。
- 不要只验证一个架构，也不要在架构版本不一致时发布。
- 不要在 AUR 成功前保存新 ETag；否则失败部署不会自动重试。
- 不要把 `upstream.env`、下载产物或 API 响应发布到 AUR。
- 不要让不同架构使用相同本地 source 文件名。
- 不要在要求 GitHub 保持 `SKIP` 时回写真实 checksum。
- 不要依赖 `data.tar.gz`、`data.tar.xz` 或 `control.tar.xz` 永远固定。
- 不要在 GitHub 包目录提交 `.SRCINFO`。
- 不要给预编译二进制包漏掉 `options=('!strip' '!debug')`：默认 strip 可能破坏 Go/Rust 二进制，debug 包成倍增大体积。
- 不要只看 GitHub Action 绿色；验证 AUR Git 内容与 RPC 状态。
- 不要为触发首次发布默认伪造旧版本；优先显式首次发布/force 路径。

## 交付报告

最终报告必须包含：

- 选择的发布通道、包类型与版本来源。
- 新增/修改文件。
- checksum 归属：GitHub `SKIP` 或固定值、AUR 是否由 `updpkgsums` 生成。
- 已运行的本地和远端验证及结果链接。
- AUR Git/RPC 验证结果。
- 未验证项、索引延迟或剩余风险。
