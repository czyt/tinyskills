# GitHub Actions 与发布

## 仓库布局

```text
rootfs.lock.json                # immutable upstream URL/digest/provenance
image.toml                      # downstream version + exact kit commit
profiles/{cleanup,lightos}.toml # policy, not secrets
profiles/masked-units.txt       # recipe-specific systemd policy
scripts/                       # fetch/stage/package/check/probe/publish
tests/fixtures/                # explicitly synthetic platform setup
.github/workflows/
  validate.yml                 # source/process/profile checks
  refresh-rootfs.yml           # latest discovery, reviewed lock change
  candidate.yml                # real payload + final artifact gates
  probe-systemd.yml            # exact accepted candidate, real PID1
  publish-rc.yml               # promote exact artifact, dual push/readback
docs/acceptance.md              # passed/failed/unverified evidence
```

不凭空设计全部脚本。优先读取并复用 `https://github.com/dockers-x/pond-oci` 的已审核脚本：
`scripts/package-desktop.sh`、`check-hardlinks.py`、`stage-desktop.sh`、`probe-systemd.sh`、
`.github/workflows/probe-remote-desktop.yml`、`probe-systemd.yml`、`publish-rc.yml`。
固定源提交、核对其 CI，再提取 generic mechanism；Pond 仓库 keyring/compositor/path/masks 必须换为目标发行版策略。
参考项目不是所有未来版本都正确的依赖，不能复制其旧 acceptance 声明当新项目证据。

## 可复用 source gate

以下示例要求仓库已有 unittest、真实 profiles；缺文件先补接口和测试，不上传空成功报告。
kit pin 是实例参数，必须换为已审查 40-character commit。

```yaml
name: Validate recipe
on: [push, pull_request, workflow_dispatch]
permissions:
  contents: read
jobs:
  source:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
        with:
          persist-credentials: false
      - run: python3 -m unittest discover -s tests -v
  toolkit:
    runs-on: ubuntu-24.04
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
        with:
          repository: ca-x/oci-kit
          ref: '<reviewed full commit>'
          path: oci-kit
          persist-credentials: false
      - run: rustup toolchain install stable --profile minimal --target x86_64-unknown-linux-musl
      - run: cargo +stable build --locked --release --manifest-path oci-kit/Cargo.toml --workspace --bins --target x86_64-unknown-linux-musl
```

这是 source gate，不是独立完整构建器。candidate workflow 还必须依次执行：

1. 验证 GitHub server/Actions 环境及 exact pins；最小 token 权限。
2. 安装 runner 依赖、编译固定 kit/remoted/frontend；Cargo locked、frontend lockfile immutable。
3. rootfs-fetch 验证已锁 archive；exact hash cache，无 restore fallback；验证成功才 save。
4. 独占 staging、签名包事务、记录 pacman -Q、离线安装、cleaner/hook/masks。
5. raw-layer 打包和 config 检查；完整 tree/hardlink 比较。
6. 从最终层验证已安装程序 hash、运行 init/desktop；不用早期 staging 成功代替最终层。
7. 仅全部通过后保留候选 artifact，短 retention；report 和 image 分开命名。
8. 后续 job 读取 exact candidate run/recipe/archive hash，GitHub API 验证 success + workflow path + head SHA；不使用“最近一次成功”或 mutable latest。

大型 rootfs 测试是 workflow_dispatch/manual gate，source gate 快速运行。启动一个 run 后记录 ID，确认 live 时只观察，不因 observation timeout 重启。
诊断日志打印先 `::stop-commands::<random token>`，结束恢复，防止日志内容被解释成 workflow command；始终有大小界限和脱敏。

## 版本与晋级

- Hash-only rootfs 不等于版本。`image.toml` 定下游 `0.1.0`；开发版 `0.1.0-dev.g<revision>`，RC `0.1.0-rc.1`，稳定 `0.1.0`。
- 每个版本锁 rootfs hash、kit/remoted/recipe commit、候选 digest、boot run、用户批准的 exact version。
- tag 必须与声明一致，RC 不自动晋级 stable/latest。用户批准 rc.1 不是批准 rc.2。
- 对已验收 OCI 晋级版本，只改 version label：先抓 raw config，`umoci config --no-history --config.label ...`，再抓 raw config，比对仅该 label 不同、全部 layer descriptor 完全相同。回读 raw 而不是 Skopeo 规范化 config。
- 从晋级 artifact 再跑 boot gate。两 registry 使用这一个 artifact，不分别 rebuild、不仅凭版本字符串认定相同。

## 凭据与双 registry

沿用用户组织现有变量约定，不显示 secret 值：

```yaml
env:
  DOCKERHUB_IMAGE: ${{ vars.DOCKER_IMAGE || secrets.DOCKER_IMAGE || format('{0}/pond-oci', secrets.DOCKERHUB_USERNAME) }}
  GHCR_IMAGE: ghcr.io/${{ github.repository }}
```

`pond-oci` 是案例默认名称，创建新项目时明确替换；不能误推其他镜像。
有效凭据可能来自组织，repo secrets list 为空不等于 Actions 无凭据；组织 API 403 也不等于 secret 不存在。先运行只输出布尔值的可用性预检，不升级 token scopes 或读取 secret。

发布 job 最小权限 `packages: write`，创建 Release 才加 `contents: write`；其他 build job `contents/actions: read`。
凭据只在测试后的发布 step 使用；通过 stdin 登录，临时 authfile、EXIT 删除；不传给 build args/env，也不交给任意 rootfs 程序。

```sh
printf '%s' "$DOCKERHUB_TOKEN" | skopeo login --authfile "$auth" \
  --username "$DOCKERHUB_USERNAME" --password-stdin docker.io
printf '%s' "$GH_TOKEN" | skopeo login --authfile "$auth" \
  --username "$GITHUB_ACTOR" --password-stdin ghcr.io
skopeo copy --authfile "$auth" --preserve-digests \
  "oci-archive:$archive" "docker://$image:$version"
skopeo inspect --authfile "$auth" --raw "docker://$image:$version" > remote-manifest.json
skopeo inspect --authfile "$auth" --config --raw "docker://$image:$version" > remote-config.json
```

发布前检查版本不存在，或存在时 digest 已相同；不同则 STOP，不覆盖。
只有明确 manifest/name unknown 才是不存在；denied、unauthorized、429、超时都不是。
注册表拒绝 preserve-digests 时保留失败证据、检查媒体类型/压缩，不静默删 flag 改成不同 artifact。
两边 manifest SHA 与准备 manifest 相同、raw config 等价后才创建 prerelease。
若交付的是公开镜像，再以匿名身份回读两边 manifest/config；有凭据 push 成功不证明新 GHCR package 已公开。
在 GitHub runner 检查 package visibility 和 `skopeo inspect --no-creds`，无需把 registry token 交给 LightOS 实例。
上传小 receipts（来源 lock、config、manifest/archive hashes、镜像 digest 列表），不要求把数 GB OCI tar 再当 release asset 上传。

## 修复与发布后核验

若 job 已 terminal failure：读具体失败 step、保留 primary error、最小修复源码、GitHub 重验。
不可移动或覆写已推 version tag。runner transient 问题可对同一不可变 tag 重跑失败 job，但必须先回读两 registry/Release 状态；已发布同 digest 只跳过，不重复覆盖。
若 release workflow 本身有 bug，修复 main 后使用经授权且绑定已验收 source 的手动恢复流程，或请求新 RC；不能悄悄把旧 tag 改指新提交。
最终核对 remote tag SHA、GitHub run conclusion、Release prerelease 标志、registry digests、工作树及剩余平台 gate。
