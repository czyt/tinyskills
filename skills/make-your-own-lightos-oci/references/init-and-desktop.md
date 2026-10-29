# CLI、平台初始化与桌面

## 已有工具及支持边界

工具源：`https://github.com/ca-x/oci-kit`。开始时读取所固定提交的 README、SPEC、CLI 源码及 CI，不盲信此 skill 的历史 pin。

| 工具 | 输入/行为 | 不能替代 |
|---|---|---|
| rootfs-fetch | 通用 source JSON 或 HTTPS URL+SHA；原子下载、重复摘要校验 | 发行版 latest 发现、上游真实性/许可审查 |
| rootfs-inspect | tar/gz/zst 静态元数据；重复 select/text，小普通 UTF-8 文件 | 安全提取器、完整运行验证 |
| rootfs-cleaner | 已标记离线 root；精确相对路径策略；默认 plan | 包卸载器、事务回滚、运行系统清理 |
| lighos-init | LightOS 专用；离线 Arch keyring 准备、安装 hook、post-setup apply | 通用 distro init、账号/SSH/远程 auth 初始化 |

名称是用户约定的 `lighos-init`，不是 `lightos-init`。先读取对应提交 `--help` 或 CLI 定义，命令参数必须真实存在。

source JSON：

```json
{
  "schema_version": 1,
  "url": "https://upstream.example/rootfs.tar.zst",
  "sha256": "<64 lowercase hexadecimal digits>",
  "metadata": {"upstream_revision": "<immutable revision>"}
}
```

尖括号只是文档占位符，不能用于构建。可选 size 为字节数。完整 URL/metadata 会进入旁车文件，不能含长期 token。
rootfs-fetch 不是断点续传工具；缓存只放已验证公开 archive、以 exact SHA 作 key，不缓存已初始化目录。

cleanup policy 是显式精确路径，不是 glob：

```toml
schema_version = 1
[[remove]]
path = "etc/machine-id"
reason = "Generate per instance"
[[remove]]
path = "var/lib/dbus/machine-id"
reason = "Do not clone D-Bus identity"
[[remove]]
path = "var/lib/systemd/random-seed"
reason = "Do not clone entropy state"
[[remove]]
path = "etc/pacman.d/gnupg"
reason = "Discard build-private trust; retain packaged public keyrings"
```

另外枚举存在的已知 SSH host key、seed/remote env、平台/kit 完成状态和下载缓存。先审计再列路径，不把 `ssh_host_*` 当 cleaner glob，也不盲删整个 `/etc/ssh`。
清理不修复上游泄露：若曾把秘密封进 layer，丢弃该 artifact 并轮换秘密。

## 初始化契约：三时刻、三个 owner

| 时刻 | owner | 动作 |
|---|---|---|
| 物化后、boot 前 | LightOS | 注入 `/etc/lightos/seed.env`、setup unit/script |
| 首次启动 | 平台 setup | 建账号/skel、密码/地区等平台设置、消费 seed、写 `/var/lib/lightos/initialized` |
| post-setup | Rust kit | 等平台成功、恢复配方声明 keyrings、写 kit 自己的幂等状态 |
| 后续运行期 | LightOS admin + remote 程序 | 注入/保留 remote/SSH 设置，按启停策略操作服务 |

这来自已检查版本的平台实现，不保证未来版本不变。应核对当前平台源码，**不读实际 seed/remote env 内容**。
初始化标记不是远程配置已到齐证明。禁止让 kit 接收密码再另建账号/auth；installer 的 `stdin` 凭据协议不等于 OCI 平台协议。

Arch/Pond 示例：

```toml
schema_version = 1
pacman_keyrings = ["pond"]
post_setup_services = [
  "lightos-remote-desktop.service",
  "lightos-remote-desktop-session.service",
]
render_node_services = [
  "lightos-remote-desktop.service",
  "lightos-remote-desktop-session.service",
]
```

`render_node_services` 是 post_setup 的子集。安装只是添加 kit drop-in，不替换/enable/start 平台或 package unit。
运行时 `apply --config /etc/oci-kit/lightos.toml --apply` 由 unit 执行；默认没有末尾 `--apply` 只是计划。
缺平台 marker 使用失败 assertion，而不是 Condition 跳过后仍被依赖方误当成功。
stdout 是一个可能 pretty-print 的 JSON 文档，不按每行 `json.loads`；journal 必要时先 sync，用完整文档 decoder。

render generator 发现已映射 DRM render 字符设备的 numeric GID，生成显式服务的 additive SupplementaryGroups drop-in。
它不修改设备、不读取硬件、不保证 GPU 工作；权限是 group 范围，不是单设备 ACL。设备晚到需 reload，运行进程不能凭空获取新组；不能为此擅自重启持久 session。

## 桌面预装与 native owner

### 桌面已存在，还是从裸 rootfs 安装

先输出一张 manifest，不凭发行版名称猜已安装组件：

| 项目 | 审计证据 | 缺失处理 |
|---|---|---|
| init/包管理器 | systemd 可执行文件、pacman DB、os-release 实际目标 | 非 Arch/systemd 转对应 adapter，不套下面命令 |
| compositor | `/usr/bin/niri`、wayland session 文件、版本/实际 backend | 在受支持的签名仓库安装所选 compositor；非 Niri 另做 owner 适配 |
| shell 和品牌配置 | `qs`、shell 包、skel include 全链、QML/resources | 从可追溯的发行版包/配置来源预装；安装 quickshell 本身不等于安装 Pond shell |
| 应用/字体/portal | 包清单、desktop entries、字体、terminal、portal backend | 按所选桌面补齐，不能把测试工具当用户应用 |
| 远程 owner 运行依赖 | 固定版本 remoted 的依赖检查及实际启动 | 补已验证依赖；Pond 案例需要 Cage，不意味着交付桌面被替换成 Cage |
| session 环境 | private D-Bus、XDG runtime、Wayland/Niri socket、HOME | 用 owner 的公开机制传播；不拷贝宿主 session 环境 |

已有 Pond：保留原桌面，只安装经过实际失败证明缺失的依赖。裸 Arch：先从上游受信任的 package manifest 建立 `packages` 数组，安装 compositor、shell、原生桌面配置、应用及其依赖；不要执行完整磁盘 installer 来“顺便装桌面”。没有可重现的 Pond shell/config 来源就不能把一个普通 Niri 桌面叫作 Pond。

下面是**已有 Pond payload** 实际采用的事务形式，`packages=(cage)` 不是从裸 rootfs 安装完整桌面的包清单：

```sh
packages=(cage)
lighos-init prepare-keyrings --root "$root" --config profiles/lightos.toml --apply
bwrap --unshare-pid --unshare-ipc --unshare-uts --hostname desktop-image-build \
  --die-with-parent --bind "$root" / --proc /proc --dev /dev \
  --perms 1777 --tmpfs /dev/shm --dir /run/systemd/resolve \
  --ro-bind /etc/resolv.conf /run/systemd/resolve/stub-resolv.conf --clearenv \
  --setenv PATH /usr/bin:/bin --setenv LANG C.UTF-8 \
  /usr/bin/pacman -Syu --noconfirm --needed "${packages[@]}"
```

执行前确认 root 为可信、独占、无敏感状态的 GitHub staging。DNS bind 路径仅对应已审计的 Pond `resolv.conf -> /run/systemd/resolve/stub-resolv.conf`；其他 rootfs 先检查其实际布局，不能照搬路径。
rootfs 包事务拥有 runner 网络，但环境已清空，不转发 token、代理密码或 registry auth。记录事务后的完整包版本，再清理 build-private GPG/cache；滚动仓库会变化，rootfs hash + recipe pin 本身不能使以后重新 `-Syu` 得到逐字节相同的包集。严格重现需另锁可信包快照/版本/摘要；否则复用同一个已验收 artifact 发布两边，不宣称源码重建必然相同。

### 明确选择 compositor，再激活

先审计发行版原桌面启动链。Pond 案例是 Niri 配置 includes → `/usr/share/pond-interface/config/niri/shell` → `qs -c pond-shell`。
这些是案例，不是所有 rootfs 的固定路径。完整保留 skel、相对 include、wallpaper/sidebar、应用和 dbus/PipeWire 环境。

两条合法路线，不能混称：

1. **AUR 包路线**：审计 PKGBUILD/.install；非 root 构建、核对 GitHub 资产 checksum；在 rootfs namespace 的包安装命令上使用已验证的 `LIGHTOS_REMOTED_PACKAGE_STAGE_ONLY=1 pacman -U ...`。不得把 stage-only 永久留 Docker ENV。仅当该包版本确实支持 staging 时使用。
2. **固定源码路线**：在 GitHub 构建已审核提交的 remoted/frontend，再调用其真实支持的 `install-service --stage-only --test-root "$root"`。该 flag 是这个程序的 staging 接口，不是通用 systemd 命令。记录程序 SHA，验证最终已安装程序，不在验收时覆盖它。

**STOP — 能力与版本不匹配：**支持 stage-only 不等于支持 native Niri。核对实际包对应的 release/tag、CLI compositor 枚举、内置 unit 和 Niri 集成 CI；不能把 main 的能力归给较早的 AUR release。旧包 pre-upgrade hook 也可能先于 staging 支持，不能假设一个环境变量能让旧 rootfs 的升级变安全。存在旧激活/认证状态时先回到干净来源，不能直接试安装。

对已验证 native Niri 能力的版本，Pond 配方离线写入**非秘密**的后加载配置：

```sh
install -d -m 0755 "$root/etc/lightos"
printf '%s\n' 'LIGHTOS_REMOTE_DESKTOP_COMPOSITOR=niri' \
  > "$root/etc/lightos/remote-desktop-native.env"
chmod 0644 "$root/etc/lightos/remote-desktop-native.env"
```

先确认该固定版本的两个内置 unit 确实加载此 override；不要创建 `/etc/lightos/remote-desktop.env`，后者的认证仍由平台/remote 激活流程所有。未显式选 compositor 的默认 owner 可能仍是 Cage/Hyprland。
动态 user/HOME 绑定、平台远程 enable/disabled 策略和 late settings 必须另验；这个非秘密设置不负责创建账号、注入认证或启动服务。

远程项目：`https://github.com/ca-x/lightos-remote-desktop`，AUR 细节读其 `docs/aur.md`。
`lightos-remoted-bin` 主程序路径 `/usr/lib/lightos-remoted/lightos-remoted`。
可选 `lightos-codec-ffmpeg-bin` worker 位于 `/usr/lib/lightos-remoted/lightos-codec-ffmpeg`；ABI 必须匹配系统 FFmpeg。
没有 worker 仍可使用内置软件 H.264/JPEG；硬件编码依赖实际 GPU/驱动/FFmpeg，必须单独探测。
Hyprland cursor companion 依赖 compositor ABI，发布 archive 漏 `.so` 会在真实 capture 失败，即使 doctor 成功；不能跨版本拷贝，也不把 Hyprland 插件套给 Niri。

服务定义由 remote 程序/package 所有，不能在配方手写替代 unit。
transport 与 session 分离；升级只 restart transport，验证原 Niri/Quickshell/application 的 PID **及 start time** 均保持。
真实用户 HOME 取 passwd；canonical unit 的默认 dedicated user 不等于平台创建的用户。用程序的已验证 runtime-user 绑定机制，不直接 chown 用户整个 home 或改宿主组。

## mask 是配方，不是工具的通用黑名单

- 平台控制网络/时间/防火墙/无线/bootloader/磁盘快照时，屏蔽相应宿主控制服务。
- SDDM/getty 不应自行抢 VT；物理 seatd 按已验证 backend/平台交付策略处理。
- `systemd-firstboot.service` 若在无 console 容器失败且平台已经负责首次设置，在生产 mask 策略修正，重建镜像重跑健康 gate；不在测试 overlay 偷偷 mask。
- 不因为列表有 NetworkManager/seatd 就推论桌面只能 headless；也不为了桌面把所有宿主控制服务全部开启。
