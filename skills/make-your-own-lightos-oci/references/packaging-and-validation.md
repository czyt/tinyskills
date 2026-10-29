# 保真打包、分层验收和故障树

## 原始 tar → 唯一 OCI layer

以下仅在 GitHub root runner 的已确认独占 staging 执行；`root/layout/output` 必须位于 RUNNER_TEMP、非 symlink、不碰宿主 `/`。
工具在 runner 安装。变量必须经过格式验证；此片段不是接收任意用户路径的安全 API。

```sh
set -euo pipefail
layer="$RUNNER_TEMP/rootfs.layer.tar"
tar --format=pax --numeric-owner --xattrs --xattrs-include='*' --acls \
  -cpf "$layer" -C "$root" .
expected="$(sha256sum "$layer" | cut -d ' ' -f1)"
umoci init --layout "$layout"
umoci new --image "$layout:candidate"
umoci raw add-layer --image "$layout:candidate" "$layer"
umoci config --image "$layout:candidate" --architecture amd64 --os linux \
  --clear=config.env --clear=config.cmd \
  --config.env LANG=C.UTF-8 --config.cmd /sbin/init \
  --config.stopsignal SIGRTMIN+3 \
  --config.label "org.opencontainers.image.version=$IMAGE_VERSION" \
  --config.label "org.opencontainers.image.source=$SOURCE_URL" \
  --config.label "org.opencontainers.image.revision=$RECIPE_REVISION" \
  --config.label "eu.ca-x.oci-kit.revision=$KIT_REVISION" \
  --config.label "rootfs.sha256=$ROOTFS_SHA256"
manifest="$(jq -er '.manifests | select(length==1) | .[0].digest | split(":")[1]' "$layout/index.json")"
config="$(jq -er '.config.digest | split(":")[1]' "$layout/blobs/sha256/$manifest")"
jq -e --arg digest "sha256:$expected" '.rootfs.diff_ids == [$digest]' "$layout/blobs/sha256/$config"
skopeo copy --preserve-digests "oci:$layout:candidate" "oci-archive:$output"
```

不要用 `COPY --from=local-context` 当元数据保真方案；真实案例把 1234:2345 改为 0:0。
`ADD tar /` 也不是通用保真承诺：真实 payload 丢 TPM access/default ACL 和 root metadata。
遇到多次 builder 变换丢字段，移除变换，不堆补丁；`umoci raw add-layer` 原样封装已有 tar。

## 完整解包比较

用 GNU tar，保留 root 目录自身 metadata；真实案例 bsdtar 提取器没有恢复 extraction root mtime。
先构造固定旧 root mtime 的 tiny probe 区分 builder 与 extractor，不 `touch` final 目录。

```sh
mkdir "$final"
tar --numeric-owner --xattrs --xattrs-include='*' --acls -xpf "$layer" -C "$final"
rsync -aHAXnci --numeric-ids --delete "$root/" "$final/" > differences.txt
test ! -s differences.txt
```

必须 root、支持 ACL/xattr 的 filesystem；不能以权限不足时的空输出推断通过，保持 pipefail。
`rsync -H` 不能证明所有反方向 hardlink 错误：按 `(st_dev, st_ino)` 收集每个 root 内的普通文件路径等价类，排序后**双向比较路径组**。
不跨两棵树比较 inode 数值。既拒绝 hardlink split，也拒绝独立同内容文件被错误合并。

tiny fixture 至少包含：非 root numeric owner/GID、setgid/modes、hardlink pair、独立同内容文件、绝对 symlink、security.capability、access/default ACL、固定旧 root mtime。
真实 rootfs 再做一次全量比较；tiny GREEN 不替代大 payload。

## 验收阶梯及明确反证

| Gate | 真正观察 | 不足以证明 |
|---|---|---|
| static | 实际 config、service mask、hook、skel、无身份/auth、layer/tree 比较 | Docker build exit0 |
| Rust init | 已安装程序，两次 changed true/false；缺 marker 失败 | shell 模拟 JSON、只有 unit 文件 |
| native desktop | 原生 shell/sidebar/window、解码帧尺寸和多色、实际进程身份 | socket/Layer 存在、全黑一色 PNG |
| interaction | 真实输入事件、launcher 窗口、新应用窗口/PID；断连重连 | enqueue 成功、IPC exit0 |
| persistence | 两代 transport；owner/Niri/shell/app PID-start 不变；正常停止无残留 | 只比 PID、强制杀 namespace 才收尾 |
| systemd | 原 CMD 真实 PID1，服务依赖、无 failed units、negative seed | bwrap/chroot 内运行程序 |
| LightOS | 真平台 seed/setup/晚到设置/代理认证/禁用策略/访问 | synthetic setup fixture 成功 |
| hardware | 已映射 numeric credentials、真实 GPU/VT/codec/audio | generator 文件存在、doctor ok |

synthetic fixture 放 test-container writable overlay，不改 sealed image，不覆盖程序，使用已知假密码和非默认 UID/HOME，不读取真实用户凭据。
systemd smoke 可用 GitHub disposable Docker daemon：

```sh
docker create --privileged --cgroupns=private --network=none \
  --tmpfs /run:rw,nosuid,nodev,mode=755 \
  --tmpfs /run/lock:rw,nosuid,nodev,mode=755 \
  --env container=docker "$image"
```

保留原 CMD；仅清理精确记录的 fixture container ID。不 bind 宿主 cgroup、不授给用户实例额外权限。
等待 multi-user.target 后检查 `/proc/1/exe`、production unit ActiveState/Result、平台 seed 删除、实际 passwd HOME/skel、kit 状态与 journal。
negative seed 必须 initializer AssertResult=no、无 marker/kit state/auth。seeded 模式检查没有 failed system units。
同容器 stop/start 第二次 boot 是独立用例；手动 restart initializer 不等同重启验收。

## 故障树：每次失败只改变被证据指向的边界

| 观察 | 下一步 | 禁止 |
|---|---|---|
| 上游下载 TCP reset | 检查同一次 run/校验缓存和网络，确认终态后重试 | 取消 SHA 校验、重复启动仍活着的 run |
| DNS bind 失败、resolv.conf 为绝对 symlink | 查看真实 target，在 namespace 直接 bind target | 覆盖 rootfs 链接或挂整个宿主 etc |
| pacman 缺 public key/trust | prepare-keyrings；确认 packaged keyrings 和签名 | SigLevel=Never、伪 initialized |
| XOpenDisplayFailed | 检查父目录遍历权限和精确 X socket mount | chmod 宿主目录/设备 |
| Niri IPC 暂时 TimeoutError | owner 存活时有界重试，共用总 deadline | retry 所有协议错误或无限 wait |
| shell layer 已映射但帧单色 | 有界等待 fresh frame 并解码检测 | 降低为“文件存在” |
| diagnostics symlink/FIFO | no-follow/type/owner/size 检查，跳过并记录可选错误 | 诊断失败掩盖原始失败，阻止 evidence 写入 |
| firstboot STDIN 不存在 | 确认平台 owns setup，生产 policy mask 后重建 | fixture 临时 mask 掩盖镜像错误 |
| doctor ok 但 capture ENOENT | 检查真实 runtime companion、ABI、安装清单 | 重启持久桌面掩盖漏打包 |
| rsync 仅 root mtime 不同 | tiny old-mtime probe 区分解包器/层 | rsync -O、touch final |

诊断只收 owned regular bounded logs、进程 exe/PID/starttime/必要模块名；不抓全进程环境或 auth 文件。
保留 primary exception，diagnostics 分别 best-effort，最后独立尝试写 evidence，不能把失败转成成功。
