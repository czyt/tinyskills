---
name: make-your-own-lightos-oci
description: 从基础 Linux rootfs 制作、验证并发布 LightOS OCI 镜像。用户提到 rootfs 转 LightOS、Pond/Omarchy 桌面容器、oci-kit、lighos-init、OCI 文件元数据丢失、LightOS seed 初始化、GitHub Actions 打包、GHCR/Docker Hub 双发布时使用。覆盖发行版审计、Rust 工具、离线预装、原生桌面生命周期、实际最终层验收和 SemVer 发布；不把普通 Docker build 成功当成 LightOS 适配完成。
---

# Make Your Own LightOS OCI

交付一个**可追溯、文件保真、按平台契约初始化**的镜像，不是把 tar 塞进 registry。
先识别发行版和平台边界，再使用已有 Rust 工具；不要重新编写账号/认证初始化 shell。

## 资源路由

只加载当前阶段需要的文件：

| 阶段 | 读取 |
|---|---|
| rootfs、CLI、初始化、桌面/AUR | [references/init-and-desktop.md](references/init-and-desktop.md) |
| OCI 保真打包、故障定位、运行验收 | [references/packaging-and-validation.md](references/packaging-and-validation.md) |
| Actions、版本、双 registry、RC 晋级 | [references/actions-and-release.md](references/actions-and-release.md) |
| 校验这个 skill 的行为 | [evals/evals.json](evals/evals.json) |

## 先确定输入和交付边界

从仓库、上游 API 和已有记录读取；只有无法安全推断的决策才询问用户。

- rootfs 来源、可信 SHA-256/签名、架构、压缩格式、再分发许可。
- 发行版、init、包管理器、动态链接器；是否已有原生桌面和 `/etc/skel`。
- LightOS 注入的 setup unit、完成标记、运行期配置、设备映射；依据具体平台源码或实测，不当成永久 ABI。
- 图形目标：保留哪种 compositor/shell；远程虚拟桌面、可选物理 VT；不得把虚拟图形桌面混同无桌面交付。
- 构建位置、发布权限、registry 名称、SemVer、RC/正式通道。

默认把下载、安装依赖、编译、执行测试、格式化、产物检查放在 GitHub Actions。
本地只编辑源码、静态审阅、SSH Git、查看日志；除非用户明确放宽，不下载 rootfs/image/report artifact 到本机。

**STOP — 范围不匹配：**没有 systemd 的 rootfs、非 Arch 包管理器或不同平台初始化协议，不能直接套用当前 `lighos-init` 的 Arch keyring 适配。先实现并远程验证对应 adapter；通用 fetch/inspect/cleaner 仍可复用。不同系统 rootfs 不是同一种运行环境。

## 第一性原理

- rootfs 是目录树及其 owner/mode/link/ACL/xattr/capability 等元数据，不是只含文件内容的目录。
- OCI 是内容寻址的 layer、config、manifest；`diff_id` 对应未压缩 layer 内容，不等于压缩 blob digest 或外层 OCI tar 的 SHA。
- OCI 默认 CMD 不包含完整 LightOS runc bundle。平台负责物化、namespace、存储、网络、映射设备、身份和代理。
- 镜像不应携带 seed、实例账号密码、远程认证、SSH host keys、machine-id 或成功初始化状态。
- 清理要在最终 layer 生成前完成；后续 layer 的 `rm` 不能减掉旧层内容或抹去旧层秘密。

## 有序工作流

### 1. 固定来源并静态审计

产物：`rootfs.lock.json`、审计报告、支持范围说明。

1. 上游 latest 发现属于镜像配方，不放进通用 `rootfs-fetch`。静态解析版本字段/API；不执行上游 installer Python。
2. 普通构建只读已审查 lock；定时更新单独生成 diff/PR。SHA-only 上游仍用独立下游 SemVer。
3. 在 Actions 编译固定提交的 `ca-x/oci-kit`；fetch 验证摘要，inspect 不执行 rootfs 程序。
4. 核对 systemd、桌面会话、shell、skel includes/symlinks、包数据库、keyring 和默认 enable/mask。

```sh
rootfs-fetch --source rootfs.lock.json --output "$RUNNER_TEMP/rootfs.tar.zst"
rootfs-inspect --archive "$RUNNER_TEMP/rootfs.tar.zst" \
  --text usr/lib/os-release --select etc/os-release \
  --select usr/share/wayland-sessions --select etc/skel > audit.json
```

`--text` 只读普通 UTF-8 小文件；`/etc/os-release` 为链接时先审计链接再读实际目标。
inspect 不是恶意 archive 的安全提取器。来源或路径安全不明时停止 privileged 提取。

### 2. 构造独占、可丢弃 staging

产物：离线未初始化的 rootfs、显式 cleanup/LightOS profile、软件包清单。

1. 解包后保留 numeric ownership、ACL、xattr、links；检查不越出 staging，无宿主挂载/运行进程。
2. `rootfs-cleaner mark --root "$root"` 明确指定 staging；先 plan 再 `--apply`。
3. Arch 包事务前使用 `lighos-init prepare-keyrings`，保留签名验证；不伪造平台成功标记。
4. 在隔离 runner namespace 内用发行版原生包管理器安装桌面/依赖；Arch 采用完整受支持的 `pacman -Syu` 事务，不局部滚动升级。
5. 离线安装远程服务 payload，阻止 package hooks 激活账号/auth/session；检查安装结果，不靠事后 disable 补救。
6. 包事务后清除构建临时 GPG 私钥/trust、实例身份及明确缓存；保留 packaged public keyrings、软件包数据库、skel、桌面和应用。
7. `lighos-init install` 安装 Rust hook；显式服务策略屏蔽宿主控制，不无脑屏蔽桌面全部依赖。

```sh
rootfs-cleaner mark --root "$root"
lighos-init prepare-keyrings --root "$root" --config profiles/lightos.toml --apply
# 在 runner namespace 内执行已审计的签名软件包事务。
rootfs-cleaner clean --root "$root" --policy profiles/cleanup.toml
rootfs-cleaner clean --root "$root" --policy profiles/cleanup.toml --apply
lighos-init install --root "$root" --config profiles/lightos.toml
```

不向正在运行的 `/` 使用 cleaner。不用删除包文件冒充卸载。失败 staging 从来源重建，不继续打包半清理结果。
最终移除 `.oci-kit-staging` 标记，并断言没有 seed/auth/initialized/kit state/build GPG。

### 3. 接通平台初始化与桌面

产物：初始化所有权表、service 依赖图、冷启动/晚到配置用例。

- 物化时平台注入 seed/setup unit；首次启动平台创建账号、消费 seed、写完成标记；运行期平台另外注入远程/SSH 设置。
- `lighos-init` 在平台 setup 后补额外 keyring 与显式排序，不读 seed、不重建账号、不生成/复制远程认证、不接管 SSH。
- 保留 `lightos-remote-desktop.service` 和 `lightos-remote-desktop-session.service`；transport restart 不得重启仍存活的桌面 owner。
- 使用实际 UID/GID/HOME，不能硬编码 UID1000 或 `/home/用户名`。配置未到、remote disabled 和平台 marker 缺失是不同状态。
- 桌面必须是原来的 compositor + shell + wallpaper/sidebar + 应用环境，不能以空 Niri/Cage 或换成 Hyprland 代替。
- numeric render GID 授权只作用于显式服务；没有 GPU 时允许软件渲染的完整图形桌面。物理 VT 的 seat/PAM/logind 单独验证。

具体配置和 AUR 两种安装路线见 init reference；不要编造不存在的 CLI flag。

### 4. 原样封装 OCI

产物：唯一 canonical OCI archive、config/layer/hash 报告。

使用 numeric-owner pax tar + `umoci raw add-layer`，避免 builder 重新解释文件元数据。
配置 `linux/amd64`、`CMD ["/sbin/init"]`、`SIGRTMIN+3`、SemVer/source/rootfs/toolkit labels。
完整命令见 packaging reference。先用包含非 root owner、hardlink、ACL、capability、旧 root mtime 的 tiny fixture 验证打包边界，再处理大 rootfs。

**STOP — 保真失败：**若 COPY 抹 owner、ADD 丢 ACL 或 root mtime 不同，定位 source→staging→layer→解包器哪个边界改变；不得删比较项、`touch`、`rsync -O`、chmod 设备或手工“修平”差异后宣称保真。

### 5. 从实际最终产物逐级验证

产物：每项 gate 的源提交、GitHub run、artifact digest、scope/限制。

1. 源码/CLI unit、process tests 和真实 profile 安装两次；新功能先证明实际行为失败，再修根因；缺模块/编译失败不是行为回归证据。
2. 最终 OCI config 与 layer 静态检查；完整 checksum/mode/owner/link/ACL/xattr 和**双向 hardlink 等价类**比较。
3. 从最终层运行实际安装的 Rust initializer 两次，`changed=true,false`；验证 remoted hash，不替换成测试重新编译的程序。
4. 原生 Niri/Pond shell、真实已解码多色画面、输入/launcher/新应用窗口、两代 transport 和稳定 owner PID-start 身份。
5. 原 CMD 真 systemd/PID1 boot：synthetic seed、非默认 UID/alternate HOME、seed 消费、排序/幂等、无 failed units、无 seed 拒绝、remote 未被擅自激活；再测重启持久化及晚到/disabled 设置。
6. 最后在真实 LightOS 验证平台注入、代理认证/访问和桌面生命周期；物理 VT/GPU/音频等按承诺逐项实测。

不能把前一级 GREEN 冒充后一级。synthetic fixture 必须明确标识，不能复制真实账号/seed/auth。
没有真实平台授权/接口时，记录缺口，继续可安全完成的 gate；禁止凭空发明平台控制 API。

### 6. 发布并回读

产物：两个 registry 的同一 manifest digest、GitHub Release/Prerelease、可重现 receipts。

- 发布前独立 review，确认源/boot run 与锁定候选一致，用户授权的具体版本与通道一致。
- 真实 LightOS gate 未闭合时只能发布明确实验性的 RC，不称已完整适配，不更新 `latest`/stable。
- 晋级已验收产物时只允许 version label 改变；原始 config JSON、所有 layer descriptor 和文件树不变；重验晋级产物。
- 使用 `skopeo inspect --config --raw`，避免结构化重序列化隐藏未知配置字段。
- `skopeo copy --preserve-digests` 推相同 archive 至 GHCR/Docker Hub；存在相同 digest 可跳过，存在不同 digest 拒绝覆盖。
- 回读两边原始 manifest/config 与准备产物比较；上传 provenance/hash receipts，registry secrets 不进入 build/rootfs/日志。
- 网络超时先读权威远端状态，不重跑 at-most-once 发布；认证/限流错误不能当 tag 不存在。

## 禁止的捷径

- 不读取用户真实 seed/auth，不重启用户现有 session，不改宿主设备权限。
- 不关闭 package 签名验证、不 `curl | sh` 上游安装器、不 root 运行 AUR makepkg。
- 不把用户名/口令放 ENV、build args、argv、layer 或诊断 report。
- 不因 firstboot 交互失败给无人值守 OCI 硬塞 console；平台负责初始设置时在生产配方明确 mask，并重建真镜像验收。
- 不用 doctor `ok`、socket 存在、IPC enqueue 或截图 hash 变化代替真实帧/输入/应用证据。
- 不把可选 FFmpeg 包已安装等同硬件编码可用，也不把缺 codec 当成无软件桌面。

## 交接格式

只报告可回读事实：仓库/提交/tag；候选及发布 digest；GitHub run；已过/失败/未测 gate；下一项可执行动作。
发布、初始化、桌面、平台代理分开记账。保存通用经验到记忆，但不把一次故障的陈旧版本号写成永远有效的规则。
