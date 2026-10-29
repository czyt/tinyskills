# Apple 硬件专题：Intel、T2 与 Apple Silicon

## 取证范围与使用方法

Omarchy 取样：`84782475aeb885c8d05f9e85b6ad0f1a0add60e5`，研究日期 2026-10-29。以下路径相对于 Omarchy 根目录；描述的是**脚本条件、配置和外部契约**，不是每台 Mac 已经通过真机测试。

Apple 是品牌，不是单一平台。先获取准确机型/年份、CPU、DMI/PCI IDs 或设备树、现有 macOS/Recovery/分区、内核与 boot 包版本，再选路线。功能状态以当期 [Asahi/t2linux 一手资料](sources.md#apple)与真机结果为准。

## 1. 三条适配路线

| 类别 | 检测依据 | 内核/引导与交付 | 不能误用 |
|---|---|---|---|
| Intel 非 T2 | x86_64，具体修补再看 DMI/PCI | PC 风格 UEFI 路线＋逐机型 quirks | 不是所有 Intel Mac 都用 T2 内核 |
| Intel T2 | Omarchy leaf 匹配 PCI `106b:1801/1802` | T2 内核、早期输入/USB、音频/固件、风扇与启动策略 | T2 不是 Apple Silicon；检测条件本身不等于机型认证 |
| Apple Silicon | aarch64 **并且**设备树 `apple,`，或构建时可信 target manifest | 平台镜像、Asahi 类启动链、设备树、平台内核/GPU/音频栈 | 不能仅换一组 aarch64 包、套 PC ISO、套 Intel quirks |

`bin/omarchy-hw-platform` 将 CPU 与设备树证据交叉验证；`bin/omarchy-hw-aarch64-apple` 接受 `aarch64-apple`；`bin/omarchy-hw-apple-silicon` 是兼容别名。构建时目标 manifest 不应被无关宿主机硬件覆盖，真正启动后则重新探测实机。

## 2. Intel Mac 的四个源码案例

调用入口：`install/hardware/all.sh`。下面四个 leaf 各自做检测，不是“把 Apple 文件夹全运行一遍就兼容”。

### SPI 键盘：早期解密也必须能输入

`install/hardware/apple/fix-spi-keyboard.sh` 按 DMI 正则匹配部分 MacBook/MacBookPro，安装 `macbook12-spi-driver-dkms`，写 `/etc/mkinitcpio.conf.d/macbook_spi_modules.conf`。`MacBook8,1` 使用 `spi_pxa2xx_pci` 分支，其他命中型号使用 `intel_lpss_pci` 分支。

注意源码使用 `MODULES=`，可能覆盖较早 drop-in 的模块列表；不能把它当可无脑追加的通用片段。检查最终 initramfs，测试**开机输入磁盘密码**、内置键盘和外置键盘，而不只测试进桌面后的输入。

### NVMe：精确机型/节点，不是全局省电开关

`install/hardware/apple/fix-suspend-nvme.sh` 的机型集合与 SPI 脚本不完全相同，还要求固定 PCI 路径下的 `d3cold_allowed` 存在。它生成 `omarchy-nvme-suspend-fix.service`，开机将该节点写为 `0`；不是遍历所有 NVMe，也不是每次 suspend 的 sleep hook。

迁移时保留检测与撤销条件。验收挂起/睡眠恢复（suspend/resume）、待机耗电与存储错误；该修补不是 hibernation 的 swap/resume 配置，不要让“能唤醒”掩盖显著耗电/温度回归。

### Broadcom：Intel 与 Apple Silicon 的相反约束

`install/hardware/apple/fix-brcmfmac-supplicant.sh` 先排除 Apple Silicon；再匹配 T2 或 Apple DMI＋指定 Broadcom PCI IDs。它写 `options brcmfmac feature_disable=0x82000`，针对特定 WPA2/WPA3 握手路径。

**不能复制到 Apple Silicon**：同一参数可能让其固件命令超时、扫描失效。迁移 `migrations/1786391100.sh` 也包含排除逻辑。

另一个 `install/hardware/fix-bcm43xx.sh` 对特定旧 PCI IDs 安装 `broadcom-wl-dkms`，不是上述 `brcmfmac` 路线。先判驱动和设备，再选 workaround；不要同时装所有 Broadcom 方案。

## 3. Intel T2 的完整集成链

固定取样的 `install/hardware/apple/fix-t2.sh` 请求：

| 内容 | 包或配置 | 必须验证 |
|---|---|---|
| 内核 | `linux-t2`、`linux-t2-headers` | 实际启动版本、模块 ABI，安装了不等于已选中 |
| 音频/固件 | `apple-t2-audio-config`、`apple-bcm-firmware-fetcher` | 音频配置、固件获取结果，不能只看包存在 |
| 风扇 | `t2fanrd`、`t2fanrd.service`、`/etc/t2fand.conf` | 单/双风扇、温控、服务运行与日志 |
| 运行时模块 | `/etc/modules-load.d/t2.conf` 的 `t2bce_vhci`、`hci_bcm4377` | 目标内核确实提供模块 |
| early boot 输入 | `/etc/mkinitcpio.conf.d/apple-t2.conf` | `t2bce_vhci` 与 HID/USB 模块进入真实 initramfs |
| 引导参数 | `/etc/limine-entry-tool.d/t2-mac.conf` | IOMMU、睡眠参数只在相应机型/内核验证后使用 |

当前 leaf 已从旧 `apple-bce` 路线切到 `t2bce_vhci`；不要复活旧教程的模块名。脚本本身没有最后的 initramfs/boot 重建调用，服务 enable 也不等于已运行；整条安装流水线必须收尾并重启验证。

固件 fetcher 依赖可用的 macOS 固件来源；若已清除 macOS，要按 t2linux 当期文档准备匹配的 macOS/Recovery 提取路线。不得先擦掉唯一来源再假设 Wi-Fi 会自动可用；firmware 提取、授权与再分发应分别审查。

### 安全反例：不能照搬的 T2 仓库配置

固定取样的 `install/hardware/pacman.sh` 给 T2 追加 `[arch-mact2]`，且明确使用 **`SigLevel = Never`**。这是记录到的实现缺口，**不是本 skill 推荐做法**。

自己的发行版应审查来源、隔离构建/镜像必要包、建立可验证的签名和可信 keyring；若无法建立信任链，该组合标为未支持/实验，不通过关闭验签来交付。不要声称“Omarchy 的全部硬件包都已有同样签名保证”。

## 4. Apple Silicon 的平台契约

### 包集合与仓库不是 CPU 判断的附属项

`bin/omarchy-pkg-defaults` 合成 base＋aarch64＋Apple 层。`install/omarchy-aarch64-apple.packages` 的 Apple 层包含：`omarchy-mac`、`omarchy-mac-boot`、`asahi-bless`、`avd-fw`、`libva-v4l2_request-avd`、`widevine`、`wf-recorder`。

包表明确把 kernel/boot chain 留给 Mac 镜像，把关键 GPU/扬声器/音频依赖留给 `omarchy-mac`。它不是完整驱动实现或全部传递依赖清单；`widevine` 等附加项还需核对自己的分发策略。

固定取样的 `default/pacman/aarch64-apple/pacman-edge.conf` 只有 Apple 的 edge 组合，按 `[omarchy] → [asahi-alarm] → [core] → [extra] → [alarm]` 排序，使用 `Required DatabaseOptional`。Omarchy 同名构建优先；这套来源包含 Arch Linux ARM/Asahi 衍生源，不是官方 Arch x86_64 仓库。不能随意换次序或混用另一套内核/Mesa。

### 引导链由平台所有者维护

Asahi 类平台需处理 Apple 启动策略、m1n1、后续引导器、DTB、vendor firmware 和恢复。Omarchy `docs/lifecycle-dispatch.md` 描述其 Mac 链为 `m1n1 → U-Boot → Limine`，不是所有 Asahi 发行版都用同一末级 loader。

`bin/omarchy-lifecycle-dispatch` 将 boot 操作委托给 `omarchy-mac-boot` 的 `/usr/lib/omarchy/mac-boot/<operation>`，运行时 setup 委托给 `omarchy-mac` 的 `/usr/lib/omarchy/mac/<operation>`。必需 boot 入口缺失/不可信要失败；可选 runtime 操作可能 no-op。root-owned、不可被其他用户改写、非 symlink 的入口检查是可复用的扩展边界。

`install/hardware/platform-setup.sh` 调度平台 setup；镜像首次启动有延迟硬件队列，平台要求重建时写 boot-rebuild 请求，由统一阶段处理。不能在 builder 上按其虚拟 GPU/网络生成目标硬件配置。

### initramfs 与加密要验证最终组合

`etc/mkinitcpio.conf.d/00-omarchy-hooks.conf` 为 Apple 新基线采用 systemd hooks，但遇到既有 `asahi` 或 legacy busybox `encrypt` 路线时，该 baseline 保留已有 HOOKS 数组，后续 drop-in 仍可能继续修改；这避免 baseline 直接破坏旧 `cryptdevice=` 系统，不意味着整个 initramfs 配置不变。

`test/shell.d/fixtures/omarchy-mac-boot-mkinitcpio/` 的 90–94 drop-in 是特定外部包版本的测试 fixture，用于覆盖 asahi/vendor firmware、解密、HID、Plymouth、vconsole 的组合；**不是当前可部署的完整 boot 包**。读取它能学测试思路，不能把测试文件复制进去后宣布支持所有内核/机型。

验证目标内核 `modinfo`、实际 initramfs、固件载入、内置/扩展坞键盘解密、启动参数以及密钥撤销。保留 macOS 与系统 Recovery，不自动清盘或照搬 Intel 手册的 Secure Boot 操作。

Asahi 的[启动过程指南](https://asahilinux.org/docs/alt/boot-process-guide/)还建议每个 OS 使用独立 ESP，与对应的 Apple 启动策略/安装配对；不能把 PC 上“复用一个共享 ESP”的方案直接搬来。Omarchy 外部镜像是否采用该布局仍需查自己的实现与恢复路径。

### 声音、输入、电源与外接屏

- Apple Silicon 扬声器必须使用匹配的保护/校准及音频栈；不为“响起来”绕过保护直接驱动扬声器。
- 内置显示器、GPU 渲染、视频编解码、HDMI/USB-C/Thunderbolt 是不同子系统；不能以桌面出现推断外接屏和硬件解码可用。
- `bin/omarchy-hibernation-setup` 对 Apple Silicon 直接跳过，`bin/omarchy-setup-direct-boot` 拒绝相应 direct EFI 操作；不要宣称已具备 PC 式休眠/直启。
- Touch ID、摄像头、休眠/待机、外接屏和特定 SoC 功能按当期功能表与平台包验证，不能从检测脚本或可选 hook 推断已实现。
- `bin/omarchy-brightness-display-apple` 的 `asdcontrol` 路线是某些 Apple **外接显示器**，不是 Mac 主机支持证明，也不是所有屏幕的统一接口。

## 5. Git 历史：读 diff 后可提炼的教训

| 提交 | 改变 | 可迁移原则 |
|---|---|---|
| `9cb3640c9`，2026-08-07 | T2 睡眠参数与双风扇默认值；不再默认 tiny-dfr | 旧用户态 daemon 与新内核能力可能冲突，安装与旧用户迁移都要覆盖 |
| `e1b0e5e9b`，作者时间 2026-10-10 | Apple 平台检测、包清单、仓库、dispatcher、hook 组合接入上游 | aarch64 不是平台；boot/解密组合和 Intel quirk 排除必须一起设计 |
| `5d8cc3313`，2026-10-22 | Apple 模板删除 `[aur]`，与外部 installer 的校验同步 | 主仓配置变更可能有外部工厂依赖，不能只改一个模板就发布 |

取证命令（只读）：

```bash
git -C "$OMARCHY_SRC" log --oneline -- install/hardware/apple install/omarchy-aarch64-apple.packages
git -C "$OMARCHY_SRC" show 9cb3640c9 -- install/hardware/apple/fix-t2.sh
git -C "$OMARCHY_SRC" show e1b0e5e9b -- etc/mkinitcpio.conf.d/00-omarchy-hooks.conf
git -C "$OMARCHY_SRC" show 5d8cc3313 -- default/pacman/aarch64-apple/pacman-edge.conf
```

时间使用提交自身作者时间；不同日志格式/本地时区可能出现前一天，不用日期代替 SHA。

## 6. 文档冲突与真机验收

取样的 `manual/44-mac-support.md` 仍说 M 系列不直接安装、Intel 安装会清盘；代码已含 Apple Silicon 接口。正确结论是**存在平台集成，但不能据此证明主 ISO 能直接安装 M 系列**。外部镜像/安装器、平台包与真机证据要另查；也不能把该 Intel 清盘说明无条件套到 Asahi 路线。

每个机型记录 `model / SoC或PCI / macOS固件 / 内核 / m1n1与后续boot / GPU与音频栈 / 安装介质 / 测试结果`：

| 阶段 | 必测项目 |
|---|---|
| 安装前 | 数据备份、macOS/Recovery 可启动、足够空间、固件来源、平台支持等级 |
| early boot | 冷启动、内置/USB 键盘解密、根存储/固件、恢复入口 |
| 桌面 | GPU/多屏、缩放、输入法、Wi-Fi/蓝牙、音频保护、摄像头、指纹（若宣称支持） |
| 电源 | 风扇/温度/电池、合盖、睡眠唤醒、待机耗电，不对未支持项强行套参数 |
| 维护 | kernel/DTB/firmware/boot 成组更新、失败恢复、Mac/Linux 启动选择、升级后 Recovery |

若固件缺失，停在获取/离线准备阶段；若 hook 混用，恢复到已知良好组合并检查最终 initramfs；若机型无公开支持证据，标为实验并停止生产承诺。遇到信任链失败、温控或扬声器保护异常，停止使用相关功能而不是绕过。
