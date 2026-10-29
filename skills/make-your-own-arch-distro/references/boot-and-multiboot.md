# 引导、加密与多系统

## 1. 明确启动链，不把 bootloader 当黑盒

```text
UEFI → EFI loader / UKI → kernel + initramfs → unlock + mount root → systemd
BIOS → 平台引导代码 → bootloader → kernel + initramfs → root
Apple Silicon → Apple 授权/启动政策 → 平台启动链 → Linux 引导器 → kernel + DTB → root
```

第三条不能改写为普通 UEFI PC。Asahi/m1n1/U-Boot 等职责见 Apple 专题。

| 选择 | 条件与责任 |
|---|---|
| systemd-boot | UEFI 路线；规划 ESP/XBOOTLDR、内核/UKI 位置和启动项 |
| GRUB | 需要其受支持的 BIOS/UEFI/文件系统功能；加密读取能力、模块与参数独立验证 |
| Limine | 项目需要相应入口/快照整合；检查版本与平台扩展，不能把 Omarchy 脚本当通用规范 |
| 设备专属启动包 | Apple/SoC 等平台所有者维护 boot policy；通用生命周期通过受限接口调用 |

## 2. 存储方案先于安装命令

输出分区/子卷图、mount points、UUID、加密边界、ESP 空间预算与恢复策略。ESP 必须装得下拟保留的内核/UKI 与备份，不能照抄固定小尺寸。

Btrfs 建议将系统根与用户/可再生缓存分开；`/var/lib/pacman` 必须与其所描述的系统处于一致恢复单元。数据库、虚拟机镜像、容器存储等是否独立子卷，要单独列备份/恢复契约。

UKI 把内核、initramfs、cmdline 等组合为一个 EFI 制品，但不自动解决签名私钥管理、LUKS 解锁、根文件系统回退和数据兼容。`/boot` 在加密内还是外，与 bootloader 能读取什么一致。

## 3. 加密与 Secure Boot

- 使用 LUKS 时，记录 LUKS UUID、密钥槽和可信恢复方式。header 备份离机加密保管；它包含可攻击的 keyslot 材料，不能放公开日志/仓库。
- TPM/FIDO2 解锁必须有人工 recovery key；固件/测量变化、TPM reset、硬件更换均要测试。
- 使用 systemd-cryptsetup、mkinitcpio busybox 等不同方案时，从对应文档生成一致 hooks 与参数，不同时混用 `cryptdevice=` 和另一套未经验证的解密配置。
- Secure Boot 是固件→loader/UKI/内核→模块的策略，不等于硬盘加密；Arch ISO 默认行为、自定义 ISO 和安装后系统逐一验证。
- **STOP**：用户自己的 UEFI key enrollment、删除平台密钥、TPM 清除与磁盘加密变更均需明确确认；不能为“安装成功”静默关闭安全功能。

## 4. Windows 共存的保守路径

1. 在 Windows 记录 BitLocker 恢复密钥与恢复分区状态，关闭会导致 NTFS 处于休眠状态的 Fast Startup；缩容优先使用 Windows 自己的工具。
2. 读取 GPT 与文件系统，展示已有 ESP、Windows/Recovery/MSR 分区和拟新建 Linux 分区。不要仅凭分区序号推断用途。
3. 复用 ESP 时不格式化，Linux 使用自己的目录，不覆盖 `EFI/Microsoft`。备份分区表、Linux 所需 ESP 文件与当前 UEFI entries。
4. 选择由固件启动菜单还是 Linux loader 展示 Windows；发现/chainload 策略要与实际 bootloader 配置一致。
5. 测试 Linux、Windows、固件菜单、恢复介质和升级后的启动顺序。修改启动链可能触发 BitLocker，发布说明不能省略。

支持“保留数据”安装时，必须明确哪些分区/子卷被清空、`/home` 是否保留及 UID 冲突如何处理。自动分区计划不得在 UI 尚未确认时写盘。

## 5. 备用入口与启动健康

至少提供已测试的旧内核/UKI 或恢复介质。主内核与对应 modules、initramfs、cmdline、root snapshot 要匹配；只把内核文件换回去可能仍无法启动。

systemd 的 boot counting/automatic boot assessment 可以成为 A/B 或已知良好启动的一部分，但需要正确的条目命名、计数、成功标记、默认项及具体 bootloader 支持。只启用一个服务不等于已有完整自动回滚。

发行版健康判据应包括根可写/或预期只读状态、关键服务、登录、图形与基础网络；不要在尚未登录或硬件初始化失败时过早“祝福”版本。数据迁移不可逆时，启动回退必须附带数据兼容说明。

## 6. 修复流程的边界

| 触发条件 | 一线处理 | 仍失败 |
|---|---|---|
| UEFI 条目丢失 | 从可信介质核对 ESP 与 loader，重建本发行版条目 | 不覆盖其他系统，保存现状后人工修复 |
| 内核找不到 root | 查 UUID、加密参数、存储模块与 fstab | 使用匹配的恢复集，不随机安装 loader |
| boot 满 | 清理明确过期的本发行版制品，保留已知良好入口 | 暂停内核更新，不删 Windows 文件腾空间 |
| 自动回退没触发 | 查计数与成功标记的真实事件 | 显式恢复介质，撤回“支持自动回滚”承诺 |

依据：[boot、UKI、Secure Boot、systemd 启动评估](sources.md#引导与更新)。
