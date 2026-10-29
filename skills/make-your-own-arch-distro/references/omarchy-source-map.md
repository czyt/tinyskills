# Omarchy 源码与提交地图

## 证据边界

本地只读取样：`/home/czyt/code/others/omarchy`，HEAD `84782475aeb885c8d05f9e85b6ad0f1a0add60e5`，日期 2026-10-29。上游身份取自本地 remote：`omacom/omarchy`。没有执行安装器、驱动、更新、重置或真实系统测试。

skill 安装到其他环境后不要求这个绝对路径存在。让使用者提供自己的 `OMARCHY_SRC`，固定 SHA 再读；不要自动 checkout/reset 用户工作树。路径与 API 可能随 Omarchy 版本变化。

```bash
git -C "$OMARCHY_SRC" rev-parse HEAD
git -C "$OMARCHY_SRC" status --short
git -C "$OMARCHY_SRC" show 84782475aeb885c8d05f9e85b6ad0f1a0add60e5:docs/file-layout.md
git -C "$OMARCHY_SRC" log --format='%h %aI %s' -- install/hardware/apple
```

每项学习采用 `入口 → 依赖/调用 → 状态/失败 → Git diff → 可复用模式 → 适用限制`，不只看函数名和提交标题。

## 1. 打包与安装不是同一个仓库责任

`docs/file-layout.md` 解释主仓产出 `omarchy`（runtime/install/migrations/themes/shell）与 `omarchy-settings`（skel、系统默认、字体、branding、boot/snapper）；PKGBUILD 在外部 `omarchy-pkgs`。keyring 与 nvim 还有独立包。这个拆分能保证用户创建和 boot 安装前已具备默认值。

本取样没有给出完整 ISO 工厂、包仓库构建/签名发布服务或 Apple 外部镜像的全部实现。`bin/omarchy-apply-system` 是 ISO 在 target chroot 调用的 setup 入口，不能将它包装成“创建 ISO”的命令。

| 主题 | 精确文件/目录 | 读什么与限制 |
|---|---|---|
| 系统安装入口 | `bin/omarchy-apply-system` | root、install user/deferred、系统配置→硬件→登录→收尾 |
| 静态种子与动态用户设置 | `docs/file-layout.md`、`bin/omarchy-provision-user` | skel/finalize/resync 分开；resync 是用户明确选择的覆盖 |
| 首次用户/OOBE | `bin/omarchy-provision-owner`、`install/provisioning/omarchy-provision-owner.service` | pending、tty1、重试、wipe-pending 门禁 |
| 加密口令转换 | `install/provisioning/luks-rekey.sh` | phase/keyslot journal；retire 删除 owner 之外全部槽，不可照搬到有恢复密钥的已有磁盘；不是 volume-key 重生成证明 |
| 镜像与实机 | `install/helpers/image-target.sh`、`bin/omarchy-provision-hardware` | trusted manifest、队列、成功逐项移除、统一 boot rebuild |
| 首次图形登录 | `bin/omarchy-provision-first-run`、`install/user/first-run/` | 等服务就绪、失败不写完成标记、可选用户配置 |
| 共用表单 | `install/provisioning/setup-form.sh` | 预设白名单、取消与非零退出处理、locale/键盘/时区 |

## 2. 驱动、配置与桌面

| 主题 | 精确文件/目录 | 读什么与限制 |
|---|---|---|
| 平台识别 | `bin/omarchy-hw-platform` | CPU/DT/可信镜像 manifest 交叉校验，不是通用硬件数据库 |
| NVIDIA | `install/hardware/nvidia.sh`、`bin/omarchy-hw-nvidia-gsp` | 模块/代际/架构策略，不能永远相信固定阈值 |
| 内核选择 | `bin/omarchy-kernel` | 安装/选择与实际 boot 入口的关系 |
| Intel SOF 音频 | `install/hardware/intel/sof-firmware.sh` | 功能需求不能仅依赖机型名猜测 |
| Qualcomm 固件 | `install/hardware/qualcomm/firmware.sh` | 外部提取器、USB 根盘风险，不直接泛化到全部 ARM |
| Apple | `install/hardware/apple/`、`install/omarchy-aarch64-apple.packages` | 独立[Apple 专题](apple-hardware.md)，含 T2 签名反例 |
| Hyprland 默认/覆盖 | `config/hypr/hyprland.lua`、`default/hypr/bootstrap.lua` | 当前取样为 Lua；默认先载入、用户覆盖后载入 |
| session | `default/wayland-sessions/omarchy.desktop`、`default/uwsm/env.d/10-omarchy` | UWSM 生命周期与环境边界 |
| shell composition | `shell/shell.qml`、`shell/services/PluginRegistry.qml` | 共享服务注入、配置所有者、损坏配置保护 |
| shell 进程 | `bin/omarchy-launch-shell`、`shell/plugins/README.md` | journal、重启预算、避免半更新树 reload；插件不是独立 shell |

## 3. 更新、恢复与引导

| 主题 | 精确文件/目录 | 实际行为与不能推出的结论 |
|---|---|---|
| 更新编排 | `bin/omarchy-update`、`docs/update-process.md` | 多阶段而非单纯 git pull；部分非核心步骤可跳过 |
| 区域源 | `bin/omarchy-apply-pacman`、`bin/omarchy-refresh-pacman` | 纯数据 region、频道与回退；多文件不是原子事务 |
| 仓库策略 | `default/pacman/pacman-stable.conf`、`install/hardware/pacman.sh` | 一般包验签与 T2 `Never` 例外要分别讲，不宣称统一安全 |
| 冲突 | `bin/omarchy-update-system-pkgs-when-conflicted` | 特定无主文件隔离/有限重试；不是通用 overwrite 策略 |
| snapshot | `bin/omarchy-snapshot`、`default/snapper/root` | 外部 Snapper/restore 工具；Btrfs 根，不是 home/ESP 异盘备份 |
| factory reset | `bin/omarchy-system-factory-reset` | `@factory`、布局前提、分阶段擦除、共享 ESP 保护；不是安全擦除 |
| boot 默认 | `etc/limine-entry-tool.d/omarchy-defaults.conf` | 外部 Limine 工具的 UKI/入口默认值 |
| 平台 boot | `bin/omarchy-lifecycle-dispatch`、`docs/lifecycle-dispatch.md` | Apple 外部 root-owned 入口；非 Apple 分支可能 no-op |
| 更新末尾校验 | `bin/omarchy-update-boot` | 调用了检查接口不等于已经重启验证 |
| 直接启动 | `bin/omarchy-setup-direct-boot` | UEFI/平台/权限前提；不是多系统分区安装器 |
| 截图 | `bin/omarchy-capture-screenshot` | 调 Omasnap；与系统快照不是一回事 |

## 4. 读过 diff 的历史线索

以下短 SHA 在该取样历史内定位；复用时必须读对应文件 diff 并查看后续改动。

| SHA | 对应路径/行为 | 工程教训 |
|---|---|---|
| `804d13890` | `install/hardware/intel/sof-firmware.sh` 从机型门控改为 Intel SOF 功能探测 | 可选包元数据不代表硬件功能不需要 firmware |
| `967bbdd73` | `omarchy-apply-pacman`/`refresh-pacman` 接通区域源渲染 | 本地化要覆盖升级路径，临时配置的权限边界需明确 |
| `3bfea9b84` | `omarchy-snapshot` 检测空配置导致的假成功 | 保护措施要有实质产物，不只看返回码 |
| `f8c235a5e` | direct-boot 与 refresh-limine 的 UKI 查找进入正确权限边界 | “不存在”可能是探测者无权读取，不应猜测性重装 |
| `463a9a1d2` | `shell/shell.qml` 不覆盖无法读取的用户配置 | 读取默认值可降级，写回必须保护原数据 |
| `3ac43659d` | `setup-form.sh` 允许介质提供键盘/时区预设 | KEY=value 按白名单读数据，不能 root source 外部输入 |
| `e16a7e710` | first-login Git 配置、可选 GitHub 登录 | 安装必需与个人选项分开；状态检测不应触发 lazy 安装 |
| `9cb3640c9` | T2 sleep/fan、移除默认 tiny-dfr | 内核能力变化要清理旧 daemon 与历史配置 |
| `e1b0e5e9b` | Apple 平台包/检测/boot/仓库接入 | CPU 架构与平台启动契约是两层 |
| `5d8cc3313` | Apple 仓库模板移除 `[aur]` | 外部 installer 的配置校验也是变更依赖 |

## 5. 吸收模式，不继承缺口

可借鉴：包拆分、默认/用户分层、延迟硬件探测、可续跑 first-boot、受限平台扩展、清楚的更新编排和配置保护。

必须重新设计/验证：仓库签名与客户端策略、快照失败是否继续、boot no-op 的观测语义、离线依赖闭包、全新 ISO/安装工厂、多系统、机型覆盖、可重复构建与安全响应。独立发行版不得因“参考 Omarchy”省略这些责任。
