# 根文件系统、镜像工厂与 ISO

## 1. 固定输入，区分三个 pacman 配置

固定构建器版本、CPU 架构、内核、包版本/摘要、仓库世代、配置提交和签名指纹。只锁 dotfiles commit 不是可重复构建；滚动镜像地址也不是版本锁。

| 配置 | 消费者 | 检查点 |
|---|---|---|
| 构建 profile 的 `pacman.conf` | `mkarchiso`/bootstrap | 能否从干净环境取得完整依赖 |
| `airootfs/etc/pacman.conf` | live 会话 | 救援/安装时使用哪个源和 keyring |
| 目标系统 `/etc/pacman.conf` | 安装后系统 | 受测仓库、镜像与签名策略是否持久化 |

三者可以引用同一模板，但必须逐份验收。修改 archiso 构建配置不会自动配置 live 或安装后的系统。

## 2. bootstrap 用户空间

以下仅在**一次性 Arch 构建 VM**执行；不挂载实体磁盘。先以发行版可信方式安装 `arch-install-scripts`，检查 `pacstrap --help`；正式工厂用锁定仓库配置。

```bash
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/arch-rootfs.XXXXXXXX")
root_dir="$build_dir/rootfs"
mkdir -p "$root_dir"
sudo pacstrap -K "$root_dir" base linux linux-firmware networkmanager
sudo arch-chroot "$root_dir" /usr/bin/pacman -Q
sudo systemctl --root="$root_dir" enable NetworkManager.service
```

这产生“带内核包的目录树”，**没有**目标分区表、fstab、bootloader、用户或可用密码，不能当成完成安装。`base` 不代表内核、所有固件、网络/文件系统工具都齐全。上面的仓库随时间滚动，只适合作为学习样例。

`-K` 创建新 pacman keyring，而不是复制宿主签名私钥；构建用 keyring 与最终设备自己的本地 keyring 是两个生命周期。公开发行公钥可以共享，本机生成的私钥不能克隆。封装镜像前删除生成器私有状态，first-boot 在需要的平台重新初始化并 populate 受信任 keyring。

### 两种目标部署路线

1. **目标侧安装包**：挂载明确的目标根，再通过 `pacstrap -C <locked-config>` 安装包闭包。安装器生成目标 fstab 和引导配置。
2. **部署预构建 target rootfs**：通过 `tar`/SquashFS/文件系统镜像保留 UID/GID、权限、ACL、xattr 和 capabilities，校验 rootfs 与包清单一致；然后生成设备专属配置。不能直接克隆运行中的构建机 `/`。

rootfs 归档示例选项：`tar --numeric-owner --acls --xattrs --one-file-system`。先确认树下没有 `/proc`、`/sys`、`/dev` 等未卸载的 bind mount；跨文件系统的设计不能被 `--one-file-system` 静默漏掉，需单独打包并记录。

## 3. 通用镜像封装前的去身份化

只对本次构建的根目录操作，清理清单与例外必须进入构建日志：

- `/etc/machine-id` 按 systemd generic image 规则置空/设为未初始化状态；区别会影响 `ConditionFirstBoot=`，不要将它当作发行版唯一的完成标记。同时检查 `/var/lib/dbus/machine-id`：不能遗留可被 systemd 回用的旧 ID，通常让它正确链接到 `/etc/machine-id`。
- 删除 SSH host 私钥、用户 token、Wi-Fi 凭证、shell history、安装缓存中的密码、构建日志中的秘密和随机种子；设备首次启动再生成。
- 不克隆 `/etc/pacman.d/gnupg` 的私有本机密钥；保留发行版公钥包与初始化步骤。
- 不把 builder 的 fstab、磁盘 UUID、显卡探测结果、MAC 地址或 home 内容放进通用镜像。
- 清理 live autologin、无密码 sudo、救援 SSH、安装器自启动及测试证书；目标系统用明确的锁定账户状态。
- 预制加密镜像必须有每台设备独立的 volume key。只改 LUKS passphrase/keyslot 不会改变共享 volume key，不能据此宣称克隆镜像已获得加密隔离。

以“两台独立安装设备”的 machine-id、SSH host key 指纹、pacman 本机 keyring、加密卷身份与秘密来源作为去克隆化测试，而不是只 `grep` 构建脚本。

## 4. 首张 live ISO 的最小闭环

先运行 `bash examples/first-iso.sh --help`。脚本从本机 archiso 的 `releng` 复制 profile，只在显式确认的一次性 VM 构建，输出 ISO、SHA-256、构建器版本和 profile。它继承官方 profile 的 live 登录策略，**不提供生产安装器或桌面**。

关键输入：

| 文件 | 职责 |
|---|---|
| `profiledef.sh` | ISO 标识、架构、构建模式、启动模式、文件权限、rootfs 压缩 |
| `packages.x86_64` | live 软件包，不是所有桌面/硬件可选项的离线闭包 |
| `airootfs/` | live 文件覆盖层；包也可能写同一路径，必须检查最终镜像 |
| profile boot 配置 | ISO/USB 启动入口，不能替代安装后 bootloader |
| `pacman.conf` | 构建来源，不自动复制给 live/target |

不沿用过时的 `airootfs/root/customize_airootfs.sh` 教程；使用当前 archiso 支持的包、文件、权限和服务机制。正式品牌内容做成包，而不是不受包管理的覆盖脚本。

## 5. 从 live 到安装介质

- 选择包安装还是解包 target rootfs；两者均验证签名和摘要。
- 离线模式收集**所有可选组合的依赖闭包**，做带签名数据库的本地仓库。缓存里“有几个包”不等于能离线安装；撤掉网卡做真实安装测试。
- rootfs/内核/initramfs 与镜像启动参数一起版本化。目标 initramfs 应按目标硬件重新生成，不能把 live 的 `archiso` 启动 hooks 原样带过去。
- USB 写盘是另一个危险阶段；本 skill 不给默认 `/dev/sda` 写入命令。展示盘标识与数据损失，获得确认再写。
- 官方 x86_64 archiso 工厂不自动变成 ARM/Apple 工厂；ARM 设备镜像要补 boot firmware、DTB、引导器、分区布局和真机测试。

## 6. 故障与验收

| 触发条件 | 一线检查 | 仍失败 |
|---|---|---|
| rootfs 缺依赖/离线失败 | 对比目标清单与仓库完整闭包 | 拒绝发布该组合，重建仓库世代 |
| mkarchiso 复用旧 work 导致怪异输出 | 读取完整日志，换全新 work 路径 | 固定构建器与输入，重新构建，不在旧树上补丁 |
| ISO 能启动、安装后不能 | 查 target fstab、initramfs、UUID 与 boot entries | 进可信 live 救援，保留失败盘用于回归 |
| 两台机器共享身份/秘密 | 停止分发，审计去身份化流水线 | 吊销已泄露凭证，重新生成设备身份 |

验收：列出 ISO 内文件、包清单、内核/initramfs/启动配置；QEMU/OVMF 启动到 TTY、联网与关机；安装后再独立验证。文件校验通过只证明字节一致，不证明能启动。

依据：[archiso、pacstrap、machine-id 官方资料](sources.md#根文件系统与安装介质)。
