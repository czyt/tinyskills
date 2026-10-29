---
name: make-your-own-arch-distro
description: Use when building, teaching, or maintaining an Arch Linux derivative, custom distro, rootfs, live ISO, installer, signed package repository, desktop edition, hardware port, first-boot wizard, system update, rollback, or recovery; including 从零制作 Arch 发行版、Hyprland/Quickshell 定制和 Apple/T2/Asahi 适配。
---

# Make Your Own Arch Distro

把发行版当作**可持续交付、可升级、可恢复的系统产品**，不是 dotfiles 加安装脚本。默认用中文；沿用 pacman/libalpm、Arch 包格式和成熟构建工具，先做一个可验证的纵向切片。

## 开始前

先确认现有项目与用户目标，记录：CPU/机型、固件/引导、桌面、存储/加密、在线/离线、滚动/镜像更新、维护资源及不支持项。未知项写成假设，不冒充用户决定。无现成约束时，以 **x86_64＋UEFI＋pacman 滚动更新＋一个桌面＋VM 实验**提出初版；Apple Silicon 走独立平台路线。

读取现有代码、包定义、Git 历史和工具版本；命令参数、内核/驱动组合、Hyprland 配置语言以目标版本及[一手来源](references/sources.md)为准。Omarchy 的固定取样见[源码地图](references/omarchy-source-map.md)，不是永久 API。

## 专题路由

只加载当前任务需要的手册；跨领域任务先读架构，再读相关专题。

| 任务 | 必读资料 |
|---|---|
| 产品边界、技术路线、工程结构 | [架构与生命周期](references/architecture-and-lifecycle.md) |
| bootstrap、rootfs、live/target、archiso、ISO | [根文件系统与镜像工厂](references/rootfs-and-image-factory.md) |
| PKGBUILD、pacman/libalpm、签名仓库、AUR | [包与仓库](references/packages-and-repositories.md) |
| kernel、firmware、NVIDIA、DKMS、硬件矩阵 | [驱动集成](references/hardware-and-drivers.md) |
| Intel Mac、T2、Apple Silicon、Asahi | [Apple 专题](references/apple-hardware.md) |
| Hyprland、Quickshell、KDE/GNOME、用户配置 | [桌面与 shell](references/desktop-and-quickshell.md) |
| UEFI/BIOS、UKI、LUKS、Secure Boot、Windows | [引导与多系统](references/boot-and-multiboot.md) |
| Calamares/TUI、分区、OOBE、用户初始化 | [安装与首次启动](references/installer-and-first-boot.md) |
| 更新通道、仓库世代、配置/数据迁移 | [更新与迁移](references/updates-and-migrations.md) |
| Btrfs/Snapper、还原点、救援、出厂重置 | [快照与恢复](references/snapshots-and-recovery.md) |
| CI、测试、发布、安全维护、退役 | [发布工程](references/release-engineering.md) |
| 学习模式、练习、故障演练 | [循序教学](references/learning-path.md) |

## 工作流与门禁

1. **定义产品契约**：输出支持矩阵、架构决策、威胁模型、数据布局及仓库信任链；区分 live rootfs、安装后 rootfs、ISO、磁盘镜像。不要为普通衍生版重写包管理器。
2. **做最小工厂**：版本化包清单/配置 → 干净构建 → rootfs → 启动介质 → VM 启动记录。先用[首张 ISO 实验](examples/first-iso.sh)，它不是生产安装器。产出构建输入、包版本、摘要和日志。
3. **完成安装切片**：同一后端支持预检、计划、确认、执行、续跑；构建时去身份化，first-boot 做系统/硬件/密钥，first-login 做用户会话。输出安装状态机和脱敏日志。
4. **闭合维护循环**：签名仓库世代 → 完整升级 → 迁移 → 健康检查 → 恢复演练。root、pacman 数据库、内核/initramfs/ESP 及数据迁移的恢复边界逐项列明。
5. **发布与运营**：完成新装、跨版本更新、断电恢复及真机矩阵；再发布签名制品、校验和、已知问题、升级/救援说明和支持期限。

**STOP／真实设备写入前**：展示磁盘稳定标识、保留/删除分区、ESP、加密和备份；等待用户明确确认。默认只分析、生成文件或使用明确指定的空白 VM 磁盘。

**STOP／信任链变更前**：确认签名指纹、密钥来源、吊销与轮换路径；签名失败不得改成“不验签”。

**STOP／正式发布前**：没有启动、升级和恢复证据，就标记“未验证”，不能称“可发布”。

## 输出契约

按任务交付：`目标与假设 → 来源/版本 → 决策及替代路线 → 文件与构建步骤 → 失败/恢复路径 → 实测证据与未验证项`。工程任务给真实文件、依赖和验收命令；教学任务每次一个知识点、一个练习、即时反馈，不把通读文档当掌握。

从零规划发行版时，交付物固定包含四栏：`rootfs 构建与去身份化 / live→target 部署 / ISO或设备镜像 / 安装→升级→恢复`；每栏写出工具、输入、产物与验收方式。

## 失败分支

| 触发条件 | 一线处理 | 仍失败时 |
|---|---|---|
| 包/仓库验签失败 | 校时，查镜像与可信 keyring | 停止安装/升级，回到已验证世代 |
| 没有图形会话 | TTY 查 GPU、会话、portal、用户日志 | 启动受测备用内核/桌面，保留诊断 |
| 升级/迁移中断 | 查锁持有者及持久化阶段，确认一致性 | 用匹配恢复集或可信救援介质 |
| 外部资料失效或源码不符 | 查官方迁移说明、固定提交和本地 help | 标明未知，不杜撰路径/支持状态 |

## 常见误区

- `pacman -Sy` 后装包是部分升级；`git pull` 不是完整系统版本。
- Btrfs 快照不是异盘备份，不自动覆盖子卷、ESP 或 LUKS header。
- live ISO 的包、autologin、测试密钥不能不经筛选进入目标系统。
- AUR 是构建配方，不是可信二进制仓库；不以 root 执行 `makepkg`。
- x86_64 配置不能只换成 aarch64 包就用于 Apple Silicon。
- 能显示桌面，不代表安装、更新、恢复、许可与长期维护已完成。
