# 安装器、用户初始化与设置向导

## 1. UI 选择不决定系统是否安全

| 选择 | 适用 | 必须补齐 |
|---|---|---|
| TUI + archinstall/自有编排 | 先交付、远程/无 GPU 环境 | 固定接口版本、预检/计划/确认、恢复日志 |
| Calamares | 多语言、分区可视化、已有模块生态 | 发行版 branding、模块配置/顺序、目标包和引导策略 |
| 自有 Qt/QML/其他 GUI | 特殊产品体验与硬件流程 | 完整安装后端、状态机、权限/安全审计和测试成本 |

Calamares 已将开发源迁往 Codeberg；旧网页或 GitHub 归档不是“当前模块配置”的权威。使用目标版本自带的 `settings.conf`、`src/modules/*/module.desc` 与模块配置；下表是概念映射，不是跨版本可直接复制的配置。

| 阶段 | 可能涉及的模块/职责 |
|---|---|
| 页面 | welcome、locale、keyboard、users、partition、summary |
| 执行 | partition/mount、unpackfs 或包安装、machineid、fstab、users、locale、initramfs、bootloader |
| 收尾 | 移除 live 特例、日志、umount、finished |

不要把 modules 顺序随意拼接：用户创建、`/etc/skel` 安装、驱动/initramfs 与 bootloader 顺序是依赖关系。安装 ISO 配置、installer 配置与 target 配置均独立验收。

## 2. 安装后端状态机

```text
discover → preflight → plan → user-confirmed
 → partition → format/unlock → mount → deploy
 → configure-target → install-boot → verify-target → complete
```

每一步记录：输入摘要、目标设备稳定标识、前置条件、开始/完成状态、可重试条件、撤销或救援方式。日志不可含密码、LUKS key、Wi-Fi token 或完整个人资料。

非特权 UI 只提交结构化计划；root 后端校验允许操作、目标设备、用户权限和参数。`eval`、`sh -c "$user_input"`、将配置 `source` 为 root 均不是数据接口。执行前重新检查设备身份，避免 USB 热插拔改变 `/dev/sdX`。

**STOP／不可逆边界**：展示“将格式化哪些分区、保留什么、是否改 ESP/启动顺序、加密和备份状态”，用户确认后才能 partition/format。失败后不能假装所有已格式化内容可撤销。

## 3. 在线/离线部署

- 在线先校时/验签/连通性，识别 captive portal；镜像故障不能退回未知脚本下载。
- 离线使用与镜像同世代的包仓库或签名 target rootfs，所有可选桌面/驱动必须有依赖闭包。UI 只显示本介质支持的离线组合。
- 安装时生成目标 fstab、initramfs、boot entries 与设备标识，不把 live 的网络、autologin、无密码 sudo、root SSH 和安装器服务复制进 target。
- 完成前校验包数据库、用户权限、boot 文件/UUID 和日志落盘；不能因“解包结束”就显示安装完成。

对照 [EndeavourOS 官方开发站](https://endeavouros-team.github.io/EndeavourOS-Development/)：其离线方式从 live 环境安装默认桌面，在线 netinstall 才提供更多桌面选择。可迁移原则是**先确定介质真实含有什么，再开放 UI 选项**，不是有一个 desktop 下拉框就能离线安装所有桌面。实际默认桌面与清理步骤随版本重新核对。

## 4. 分开三种初始化

| 阶段 | 权限/时机 | 内容 |
|---|---|---|
| image build | builder、无目标硬件/真实用户 | 静态包/默认值、去身份化、生成待办 manifest |
| first-boot/OOBE | root、真实硬件、登录前 | 设备身份、本机 keyring、用户创建、硬件/固件、加密密钥、启动重建 |
| first-login | 普通用户、图形/D-Bus 已就绪 | XDG 目录、默认应用、输入法、欢迎、可选 Git/指纹/账号向导 |

不要在 chroot 里等待图形会话或注册指纹；不要让 root 服务拿着用户 token 运行桌面。`/etc/skel` 只在新建 home 时播种，不能更新已有用户配置。

## 5. 可续跑、幂等且不泄密的 OOBE

持久化记录 `schema / phase / completed steps / error code / relevant identifiers`，不记录秘密。使用 root-owned、不可被用户改写的数据文件；解析白名单字段，不将其当 shell 执行。

推荐阶段：`identity → account → hardware → key-transition → boot-rebuild → validate → complete`。单步成功才标记完成，全部必需项成功才移除 pending；失败留下待办，下一次从可信阶段继续。用户可以跳过的 Git、云账号、遥测单独列为可选，不阻断磁盘安全完成。

预制镜像存在临时解锁 key 时：验证新 key 确实可解锁 → 更新引导解锁方式 → 验证启动 → 撤销临时 key → 再验证临时 key 无效。使用可恢复 journal 管理 keyslot 状态。若多台镜像共享 volume key，还需要每台独立加密卷/受控 reencryption，换口令不是加密隔离。

systemd 的 `After=` 只规定顺序，不能代替“上一步成功”。需要组合 `Requires=`、条件、失败传播或显式状态检查；即使有 `Requires=`，也要验证所需业务结果。图形就绪通过 D-Bus/通知服务可用性检测，不靠固定 `sleep 5`。

## 6. Omarchy 可借鉴的具体接口

- `bin/omarchy-apply-system`：ISO 在 target chroot 调用的系统配置入口，不是 ISO builder。
- `install/helpers/image-target.sh`、`bin/omarchy-provision-hardware`：受信任目标 manifest、延迟硬件队列、成功后逐项清除、最后统一重建 boot。
- `install/provisioning/omarchy-provision-owner.service`：pending 条件、tty1、在 display manager 前创建 owner；wipe-pending 时阻止在半重置状态新建用户。
- `bin/omarchy-provision-user`：处理 `/etc/skel` 无法静态播种的事项；fresh install 的迁移基线与已有用户分开。
- `bin/omarchy-provision-first-run`：运行用户会话步骤，失败则保留下一登录重试，不提前写完成标记。
- `install/provisioning/luks-rekey.sh`：keyslot 阶段 journal；`luks_rekey_retire()` 按其新装模型删除 owner 之外的全部槽，不仅是一个临时槽，不能直接用于带管理员/TPM/FIDO/恢复密钥的已有磁盘。自己的实现只撤销明确允许的临时槽，保留并验证规定的恢复方式；不要据此推断重新生成了 LUKS volume key。

`3ac43659d` 将介质键盘/时区预设按白名单 `KEY=value` 读取，而非 `source`；`e16a7e710` 把 Git 身份/登录移到 first-login，并避免探测状态触发 lazy shim 静默安装软件。可复用原则：安装必需项与可选个人配置分开，检测动作应无意外副作用。

## 7. 失败分支

| 触发条件 | 一线处理 | 仍失败 |
|---|---|---|
| 空间/电源/依赖不满足 | 停在 preflight，解释可修复项 | 不进入写盘阶段 |
| 分区后部署失败 | 保留日志与明确完成阶段 | 进入 live 救援，不能重新格式化“重试” |
| OOBE 断电 | 从持久化阶段续跑，核对用户/密钥现状 | 提供认证后的恢复终端，不留默认后门 |
| 网络/图形不可用 | 完成可离线的系统安全步骤 | TTY 保底、可选在线任务延后 |

依据：[archinstall、Calamares、systemd-firstboot](sources.md#根文件系统与安装介质)，[Omarchy 源码](omarchy-source-map.md)。
