# 架构与发行版生命周期

## 1. 先决定产品是什么

| 路线 | 适用 | 要承担的责任 |
|---|---|---|
| Arch 配置层/桌面预设 | 小团队、先验证体验 | 默认配置、包组合、升级兼容；不能宣称已有完整安装/恢复产品 |
| Arch 衍生发行版 | 自有安装体验与发布节奏 | 少量自有包、仓库、镜像、安装器、迁移、安全响应 |
| 大范围 fork/rebuild | 需要 ABI/编译器/内核策略差异 | 工具链、依赖重建、安全补丁及上游追踪成本显著增加 |
| 镜像/A-B 系统 | 专用设备、需要已验证的系统回退 | 镜像签名、状态分离、引导槽位、失败切换；不是给 pacman 加一个按钮 |

推荐从“小型自有仓库＋上游仓库＋受测组合”起步。新增工具应填补安装、发布、恢复的空隙，不替代成熟的依赖求解、事务锁和包数据库。

## 2. 四种制品必须分开

- **rootfs**：用户空间目录树或归档；包含 `/usr`、`/etc`、包数据库等。单独有 rootfs 不等于能从磁盘启动。
- **live rootfs**：为安装/救援启动的系统；可含临时用户、自动登录、安装器与硬件诊断。
- **target rootfs**：用户安装后的长期系统；要有自己的用户、密钥、fstab、驱动和更新渠道。
- **ISO / disk image**：前者封装光盘/USB 启动结构与 live 系统；后者含平台要求的分区/文件系统/引导结构。Apple 平台还可能有设备专用启动与固件制品。

绘出并版本化这条数据流：

```text
源码/PKGBUILD/上游仓库快照
          ↓ clean build + signatures
自有包 + 受测仓库世代 + release manifest
          ↓                            ↓
live rootfs → ISO/安装环境       target rootfs/设备镜像
          ↓                            ↓
安装计划 → 存储与部署 → first-boot → first-login
          ↓
完整升级 → 迁移 → 健康确认 → 回退/救援 → 退役
```

## 3. 包分层与配置所有权

以下是建议工程命名，不是现存上游包：

| 包/组件 | 负责 | 不负责 |
|---|---|---|
| `mydistro-release` | `/etc/os-release` 策略、版本标识、支持渠道 | 升级全部包 |
| `mydistro-keyring` / `mirrorlist` | 公钥、信任、仓库地址 | 私钥 |
| `mydistro-base` | 基础依赖元包 | 图形界面与用户密码 |
| `mydistro-settings` | `/usr/share` 默认值、`/etc` drop-in、`/etc/skel` | 覆盖已有用户配置 |
| `mydistro-desktop-*` | 会话依赖、portal 策略、桌面默认值 | 通用存储/引导 |
| `mydistro-hardware-*` | 型号/平台适配及兼容约束 | 假设构建机就是目标机 |
| `mydistro-installer` / `firstboot` | 安装后端、首次初始化 | 自己实现依赖求解 |
| `mydistro-update` / `recovery` | 编排、门禁、恢复集 | 绕过 pacman 锁和验签 |

发行版配置先放 `/usr` 的包管理默认层；管理员覆盖放 `/etc`；用户覆盖放 `$XDG_CONFIG_HOME`；状态放 `/var/lib/<distro>` 或 `$XDG_STATE_HOME`。包元数据声明 `depends`、`conflicts`、`provides`、`replaces`；不要靠脚本静默删掉其他包的文件。

示例工程布局：

```text
packages/       PKGBUILD、patch、sources、.SRCINFO
profiles/       base、live、desktop、hardware manifests
image/          archiso profile、平台镜像配方
installer/      UI、计划模型、受限特权后端
firstboot/      system units、状态机、用户向导
migrations/     有序、可续跑、带兼容说明的迁移
release/        签名清单、输入锁定、通道推广策略
tests/          构建、安装、升级、恢复、硬件验证
docs/           ADR、支持矩阵、运维/救援手册
```

## 4. 决策记录最低字段

记录 `问题 / 目标硬件 / 候选路线 / 决定 / 成本 / 配置所有权 / 失败恢复 / 验证证据 / 重新评估条件`。重点决策包括分区、加密、内核、bootloader、仓库世代、可变/不可变根、默认桌面、升级期限。

默认路线不是通用真理：UEFI x86_64 实验和 Apple Silicon 设备应拥有不同的 ADR、包清单和测试门禁。对 aarch64 另列上游来源，Arch Linux ARM、Asahi 与官方 Arch x86_64 不是同一仓库。

## 5. 生命周期退出条件

| 阶段 | 可核查交付物 | 退出门禁 |
|---|---|---|
| 原型 | 可重建配置、首次启动日志 | VM 能启动与联网 |
| 安装 | 安装状态机、离线闭包、用户初始化 | 空白盘新装、失败恢复通过 |
| Beta | 签名仓库、升级通道、恢复集 | 旧版升级及坏内核演练通过 |
| Release | 制品签名、支持表、变更/救援文档 | 发布矩阵全部有证据 |
| 运营 | 漏洞响应、镜像保留、密钥轮换 | 安全更新可传播，恢复仍可用 |
| 退役 | EOL 公告、迁出/解密/擦除步骤 | 用户可导出数据，不被失效仓库锁死 |

依据：[Arch 安装与维护、包工具](sources.md#基础与包)、[更新机制](sources.md#引导与更新)。
