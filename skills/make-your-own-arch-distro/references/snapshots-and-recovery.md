# 还原点、备份、救援与出厂重置

## 1. 先定义要恢复什么

| 机制 | 能解决 | 不能冒充 |
|---|---|---|
| Btrfs/Snapper 快照 | 文件系统同盘时间点、升级前后差异 | 异盘备份、应用一致性、整盘克隆 |
| 备份 | 磁盘损坏/丢失后恢复数据 | 自动给出能启动的系统 |
| boot fallback | 新内核/启动入口失败 | 用户数据降级兼容 |
| recovery ISO | 解锁、挂载、诊断、修复/恢复 | 任意旧系统都能无条件修好 |
| factory reset | 回到定义的初始状态 | 安全擦除、换盘加密密钥或恢复所有数据 |

快照创建退出 0 还不够：验证产生了可识别的 snapshot ID、正确子卷、可访问元数据和对应 boot/包数据库状态。

## 2. 恢复集的组成

恢复记录至少关联：

- 根 snapshot/归档与 `/var/lib/pacman`；包文件、数据库、配置属于同一个一致恢复状态。
- `/boot`、ESP、本发行版 loader/UKI/kernel/initramfs、cmdline、签名及 UEFI entries；不包含或覆盖其他系统的私有文件。
- 其他独立子卷与挂载，如 `/home`、`/var/log`、容器、数据库；列明是否保留、恢复还是前向兼容。
- fstab/crypttab、分区布局、LUKS UUID 与独立保管的 header/recovery key。
- 仓库世代、migration/schema、keyring 版本及恢复后更新规则。

**Btrfs 快照不递归覆盖嵌套子卷。** 如果把整个 `/var` 单独快照或排除，很容易出现旧系统配新 pacman 数据库。数据库应用要 quiesce/checkpoint 或使用其原生备份，文件系统 crash-consistency 不等于业务一致性。

## 3. 创建、保留与恢复

1. 计算空间与保留策略，确认旧快照不会把 Btrfs metadata 空间耗尽；qgroup/配额不是没有运维成本。
2. 更新前创建恢复集，记录 snapshot ID、包清单、boot 摘要；关键数据执行一致性备份。
3. 更新后建立对应标记，启动并验证健康。只有验证通过才提交健康状态。
4. 清理过期快照时保留已知良好与 factory 基线；遇到空间不足，不能先删掉唯一救命版本再更新。
5. 恢复时从匹配入口/救援环境选择目标集，将系统、包数据库与 boot 配套恢复，再决定数据的保留或恢复。

从只读 snapshot 启动只是诊断路线；恢复为可写根、选择新的根子卷、更新 fstab/boot 和保留 `.snapshots` 的步骤因布局与工具而异，不提供假装通用的 `snapper rollback` 一键命令。

ext4 可选文件级/镜像备份；LVM/ZFS 有各自的一致性和恢复机制。必须单独实现与演练，不能只替换 Snapper 命令名。

## 4. 可信救援的具体顺序

```text
验证救援介质 → 只读识别磁盘/分区/加密
 → 用户确认目标 → 解锁 → 挂载正确根子卷与独立 boot/ESP
 → 保存失败现场 → 恢复集或 arch-chroot 修复
 → 重建目标 initramfs/引导 → 检查 UUID/签名/入口 → 重启验证
```

根据目标实际生成挂载/解锁命令，不给默认设备名。先修复存储/空间问题，再恢复；不能在损坏文件系统上反复尝试升级。密钥无法解锁时，恢复服务不能绕过密码，也不能偷偷使用已分发镜像的共享 key。

## 5. 出厂重置是单独产品能力

定义 reset 的范围：系统默认、用户删除、网络/账号/浏览器秘密清除、外部盘排除、共享 ESP/Windows 保护。要求身份认证、明确确认与持久化阶段；重置中断后不能先启动 owner 向导再继续删除用户。

保留工厂 rootfs/`@factory` 需要定义其安全更新与过期策略。恢复旧系统后如果 keyring/软件源已过期，要有签名的过渡更新路径；不能为了“出厂后能更新”关闭验签。

普通 reset、删除目录、SSD TRIM 或改 LUKS passphrase 不等于安全擦除。LUKS keyslot 包裹的 volume key 仍可能不变；镜像若共享 volume key，应重新建立独立加密卷或执行受审查的 reencryption。出售/退役设备单独制定 crypto-erase/厂商擦除及验证流程。

## 6. Omarchy 案例

- `bin/omarchy-snapshot` 是 Snapper 与外部 `limine-snapper-restore` 的包装，`default/snapper/root` 针对 Btrfs 根；不是完整备份系统。
- `3bfea9b84` 修复“没有 Snapper 配置，循环执行零次仍报成功”的问题。测试要核对真实结果，不只看退出码/标题。
- `bin/omarchy-system-factory-reset` 依赖标准 Btrfs 布局和 `@factory`，分阶段重建启动并在重启后收尾，保留共享 ESP 的其他系统；不能移植成“任意盘恢复”。
- **Omasnap 是截图工具，不是系统 snapshot。** 不按项目名字猜职责。

## 7. 恢复演练矩阵

| 故障 | 必须观察到 |
|---|---|
| 坏内核/坏 initramfs | 已知良好入口可启动；恢复后模块/boot 匹配 |
| 快照缺失/无配置/空间不足 | 创建失败被明确报告，策略要求保护时阻止升级 |
| 错误配置/失败迁移 | 保留原文，可续跑或恢复，数据 schema 有兼容路径 |
| ESP 损坏/启动项丢失 | 从可信 USB 修复本发行版而不破坏 Windows |
| 根盘报废 | 用异盘备份在新盘恢复，证明快照不是唯一保护 |
| 重置时断电 | wipe-pending 先完成，用户初始化不会被后续清理误删 |

依据：[Btrfs/Snapper 官方与 Arch 资料](sources.md#恢复)，[Omarchy 取样](omarchy-source-map.md)。
