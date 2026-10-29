# 内核、固件与硬件支持

## 1. 把“支持硬件”拆成可测试契约

记录 `CPU 架构 / DMI 或设备树机型 / PCI-USB IDs / 内核及配置 / firmware 版本 / 模块来源 / initramfs / 用户空间 / 已知缺陷 / 受测状态`。机型营销名不能代替 PCI ID、板卡和修订版本。

硬件支持等级：启动、基本可用、完整功能、持续升级受测。不能用一张截图证明最后两级。VM 测启动和编排，不能替代实体 GPU、Wi-Fi、扬声器和电源管理测试。

## 2. 集成层次

| 层 | 处理 | 典型失效 |
|---|---|---|
| 内核 | 上游内核、受控补丁、配置、平台内核 | 驱动缺失、ABI 不兼容 |
| 固件 | 可分发 firmware 包、设备提取步骤 | Wi-Fi/蓝牙缺失、GPU 初始化失败 |
| 早期启动 | initramfs modules/hooks、microcode、解密、根存储 | 桌面内可见设备但开机找不到根 |
| 系统策略 | udev、modprobe、内核参数、电源管理 | 权限、黑名单误伤、恢复失败 |
| 用户空间 | Mesa/Vulkan、音频 UCM/ALSA、libinput、摄像头栈 | 图形加速/麦克风/解码不可用 |

启用硬件 leaf 前先检测，检测失败不应用；重复执行不叠加参数；每个 workaround 写清机型、原因、上游修复版本和撤销条件。不要把所有笔记本都加同一个 suspend 参数。

## 3. 内核与 initramfs

- 采用受支持的主内核与经验证的回退内核；平台内核不一定有可用 LTS 替代，不能拿泛用内核当 Apple/SoC 保底。
- out-of-tree 模块要匹配内核 ABI，DKMS 要有对应 headers 与构建工具。新内核可安装不代表模块已构建成功。
- 存储控制器、键盘、加密、根文件系统驱动必须在需要的启动阶段可用；验证 `lsinitcpio` 的最终产物，而不只看配置。
- 按 mkinitcpio/dracut 的实际 hook 模式区分 busybox 与 systemd 解密/键盘配置，不能混拼两套参数。
- rootfs 在构建 VM 生成时，不使用 builder 的 autodetect 结果去掉目标机必要模块。硬件相关 setup 在目标 chroot 或 first-boot 执行。
- Secure Boot 同时考虑内核/UKI 与加载模块的信任策略；只给 bootloader 签名不覆盖所有后续代码。

## 4. NVIDIA 决策

先收集 GPU PCI ID/代际、独显/混合显卡、内核、Wayland 和 Secure Boot 状态。依据当期 Arch/NVIDIA 支持表选 open/proprietary/legacy 分支；不要硬编码“所有 NVIDIA 都装某包”。

检查点：模块与内核/header 匹配、KMS、initramfs、Mesa 与 NVIDIA 用户空间兼容、Vulkan/32 位需求、外接屏、休眠、亮度、PRIME 与省电。只在模块确实可用时启用相关黑名单或参数，避免无可用驱动可启动。

Omarchy 实例见源码地图：`install/hardware/nvidia.sh` 与 `bin/omarchy-kernel` 展示了硬件探测和内核策略应分离；具体包名及判断来自固定提交，不是永远有效的推荐。

## 5. 通用真机矩阵

| 子系统 | 最低测试 |
|---|---|
| GPU | 冷启动、TTY/Wayland、加速、多显示器、热插拔、睡眠唤醒 |
| 输入 | 内置/USB 键盘、触控板、Fn、触摸屏、启动时解密输入 |
| 网络 | Wi-Fi/以太网/蓝牙、断连重连、飞行模式、captive portal |
| 音频 | 扬声器保护、耳机、麦克风、蓝牙音频、音量与休眠 |
| 电源 | 电池、充电、调度策略、风扇、合盖、待机耗电、温控 |
| 外设 | 摄像头、扩展坞、USB-C/Thunderbolt、存储、指纹 |

Apple 设备不要套用泛用矩阵结论，另外读取[Apple 专题](apple-hardware.md)。固件分发需要核对来源/许可；不从用户机器提取后直接塞进公共 ISO。

## 6. 失败分支

| 触发条件 | 一线处理 | 仍失败 |
|---|---|---|
| 新内核黑屏 | TTY 检查模块、GPU 日志及 initramfs | 启动经验证的旧内核或恢复匹配集合 |
| DKMS 编译失败 | 核对 headers、编译日志与模块支持范围 | 保留旧可启动内核，禁止标记升级健康 |
| 只有安装介质能联网 | 对比 live/target firmware、内核与网络服务 | 使用受测离线包闭包，不临时下载未知脚本 |
| 构建 VM 注入了错误硬件配置 | 删除该构建产物，修目标探测/延迟队列 | 重建并在另一机型测试，不能就地猜参数 |

依据：[内核、initramfs、NVIDIA 官方/Arch 资料](sources.md#硬件与桌面)。
