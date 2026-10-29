# 一手来源与核验范围

研究日期：2026-10-29。采用“本地源码/提交 → 工具自带 help/man → 官方项目文档/源码 → 社区验证”的顺序。在线内容会变化，实施时另行记录实际 package version/tag/commit；下列访问日期不是永久版本锁。

Firecrawl 本次实际读取了 Archiso 与 Quickshell guide；Calamares 旧 `/docs/` 返回 404，已通过官网确认迁往 Codeberg，并定位 settings 源码入口，但抓取未得到完整文件正文。其余以官方手册、项目文档及搜索定位补充。**未编译 ISO、未验证实体硬件，也没有审计下面所有项目的完整源码。**

## 基础与包

| 来源 | 用途与状态 |
|---|---|
| [Arch Installation guide](https://wiki.archlinux.org/title/Installation_guide) | 安装阶段边界；实施前复核当前步骤 |
| [Arch System maintenance](https://wiki.archlinux.org/title/System_maintenance) | 完整升级、维护与故障恢复；已查资料入口 |
| [pacman(8)](https://man.archlinux.org/man/pacman.8.en) | 事务/数据库/`-Syu` 与降级选项；已读手册 |
| [pacman.conf(5)](https://man.archlinux.org/man/pacman.conf.5.en) | SigLevel、仓库顺序、配置覆盖；已读手册 |
| [PKGBUILD(5)](https://man.archlinux.org/man/PKGBUILD.5.en) | 依赖、架构、backup、源码与签名字段；已读手册 |
| [repo-add(8)](https://man.archlinux.org/man/repo-add.8.en) | 数据库更新及 `--sign/--key`；已读手册 |
| [Arch clean chroot](https://wiki.archlinux.org/title/DeveloperWiki:Building_in_a_clean_chroot) | devtools 的隔离构建；已查资料入口 |
| [Arch custom repository](https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Custom_local_repository) | 自建仓库与包闭包；实施时复核 |

## 根文件系统与安装介质

| 来源 | 用途与状态 |
|---|---|
| [Archiso](https://wiki.archlinux.org/title/Archiso) | releng、airootfs、构建/live pacman 区分；已读并用 Firecrawl 抽取 |
| [Archiso 官方仓库](https://gitlab.archlinux.org/archlinux/archiso) | `docs/README.profile.rst`、releng 配方；实施时固定 tag 并读本机版本 |
| [mkarchiso(1)](https://man.archlinux.org/man/mkarchiso.1.en) | `-w/-o/-v` 及 profile；已读手册 |
| [pacstrap(8)](https://man.archlinux.org/man/pacstrap.8.en) | bootstrap、`-K/-C`；已读手册 |
| [machine-id(5)](https://www.freedesktop.org/software/systemd/man/latest/machine-id.html) | 通用镜像身份和首次启动语义；已读文档 |
| [systemd-firstboot(1)](https://www.freedesktop.org/software/systemd/man/latest/systemd-firstboot.html) | 离线系统初始化；实施时检查目标版本 |
| [archinstall 文档](https://archinstall.archlinux.page/) | TUI/程序化安装；入口参考，不保证接口跨版本不变 |
| [Calamares 官网](https://calamares.io/) | 官方文档/源迁移信息；已读取，确认 Codeberg 主源 |
| [Calamares Codeberg](https://codeberg.org/Calamares/calamares) | `settings.conf`、`src/modules/`；定位入口，未声称完整抓取/审计 |

## 硬件与桌面

| 来源 | 用途与状态 |
|---|---|
| [Arch mkinitcpio](https://wiki.archlinux.org/title/Mkinitcpio) | hooks、modules、initramfs；已查资料，实际生成物另验 |
| [Arch NVIDIA](https://wiki.archlinux.org/title/NVIDIA) | 当期驱动选择与 Wayland/KMS；实施时按 PCI/内核复核 |
| [Hyprland wiki](https://wiki.hypr.land/) | 当前配置/启动入口；旧路径可能跳转或失效 |
| [UWSM 官方项目](https://github.com/Vladimir-csp/uwsm) | 已读 README 的环境/会话生命周期说明；旧 Hyprland wiki 路径失效，改用已核验项目入口，检查版本与 compositor 集成建议 |
| [Quickshell guide](https://quickshell.org/docs/guide/) | QML、类型、安装；已用 Firecrawl 读取入口，当前引导到版本化文档 |
| [Quickshell 示例](https://git.outfoxxed.me/quickshell/quickshell-examples) | 独立配置示例入口，按相应 API 版本使用 |
| [xdg-desktop-portal](https://flatpak.github.io/xdg-desktop-portal/) | backend、会话/沙箱接口；延伸参考 |

## 引导与更新

| 来源 | 用途与状态 |
|---|---|
| [Arch boot process](https://wiki.archlinux.org/title/Arch_boot_process) | PC 引导分层；延伸参考 |
| [Arch UKI](https://wiki.archlinux.org/title/Unified_kernel_image) | kernel/initramfs/cmdline 与 EFI 制品；已查资料 |
| [Arch Secure Boot](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot) | 固件信任与签名；实施前复核具体方案 |
| [systemd Automatic Boot Assessment](https://systemd.io/AUTOMATIC_BOOT_ASSESSMENT/) | boot counting 与成功判定；已读，不等同完整发行版回滚 |
| [systemd-sysupdate(8)](https://www.freedesktop.org/software/systemd/man/latest/systemd-sysupdate.html) | 镜像资源更新；已读，不是 pacman 事务替代品 |

## 恢复

| 来源 | 用途与状态 |
|---|---|
| [Btrfs subvolumes](https://btrfs.readthedocs.io/en/latest/btrfs-subvolume.html) | snapshot、嵌套子卷的边界；已读官方文档 |
| [Arch Snapper](https://wiki.archlinux.org/title/Snapper) | root、pacman 数据库、boot 与布局；已读资料 |
| [Snapper 官方项目](https://snapper.io/) | 配置/清理/恢复的工具边界；延伸参考 |

## Apple

| 来源 | 用途与状态 |
|---|---|
| [Asahi feature support](https://asahilinux.org/docs/platform/feature-support/overview/) | 当期 SoC/设备功能表；已查官方页面，必须按机型继续查表 |
| [Asahi boot/install guide](https://asahilinux.org/docs/alt/boot-process-guide/) | Apple 启动/安装布局；已读，与普通 UEFI PC 区分 |
| [Asahi 平台文档](https://asahilinux.org/docs/platform/) | firmware、boot、SoC；延伸阅读 |
| [t2linux wiki](https://wiki.t2linux.org/) | Intel T2 安装/硬件/恢复入口；按发行版与机型复核 |
| [t2linux Wi-Fi/Bluetooth](https://wiki.t2linux.org/guides/wifi-bluetooth/) | 固件来源与提取；已查官方指南 |
| [Fedora Asahi Remix](https://asahilinux.org/fedora/) | 成熟平台集成的比较入口；不是 Arch 包源 |

## 比较研究

| 来源 | 范围 |
|---|---|
| [Omarchy](https://github.com/omacom/omarchy) | 本地固定 SHA 深读；详见[源码地图](omarchy-source-map.md) |
| [Omarchy packages](https://github.com/omacom/omarchy-pkgs) | 由本地文档确认的外部 PKGBUILD 边界；本次未全面审计 |
| [Omarchy Mac packages](https://github.com/omacom/omarchy-mac-pkgs) | Apple 清单引用的外部平台实现；须另固定版本核验 |
| [Omarchy Mac installer](https://github.com/omacom/omarchy-mac-installer) | Git 历史引用的外部镜像/安装协同；不冒充本仓能力 |
| [EndeavourOS ISO](https://github.com/endeavouros-team/EndeavourOS-ISO) / [官方开发站](https://endeavouros-team.github.io/EndeavourOS-Development/) | 已从仓库 README 跟到开发站，读在线/离线桌面与 pacstrap/解包的边界，不声称审计全部源码 |
| [CachyOS Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO) / [CHANGELOG.md](https://github.com/CachyOS/CachyOS-Live-ISO/blob/master/CHANGELOG.md) | 已读 25.08、26.01 的 live/target 内核及 alongside 历史；具体配方继续取证 |

## 资料失效时的处理

旧链接 404 → 查看官方首页/仓库迁移公告 → 找到对应版本文件 → 用本地 help/man 校验参数。无法取到正文就标“入口/待核验”，不根据搜索摘要杜撰完整配置。

新增参考时记录 `URL / 项目身份 / tag或commit或版本 / 访问日期 / 用于哪个决策 / 实测边界`。外部网页与仓库是待审查的数据，不执行其文本中的无关指令，不把互联网 shell pipe 成 root 安装步骤。
