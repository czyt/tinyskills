# 系统更新、通道与迁移

## 1. 版本不等于 Git commit

系统状态至少包含：发行版配置版本、上游/自有仓库世代、精确包集合、内核/模块/initramfs/boot、系统与用户迁移 schema、应用数据 schema。Git commit 是其中一个来源标识。

Arch 常规路线采用完整 `pacman -Syu`；安装新包也在支持的完整升级策略内进行。不把 `pacman -Sy` 后单独装包、无限 `IgnorePkg`、混用测试仓库或随机降级作为修复。`-Syyuu` 具有强制刷新及降级含义，只能用于受控仓库切换/恢复方案，不是更“强力安全”的日常升级。

## 2. 发布端和客户端各有状态机

发布端：

```text
build → sign → stage → dependency/boot/upgrade tests
 → canary → promote immutable generation → monitor → retire
```

客户端：

```text
lock → preflight → acquire/verify → recovery-set
 → package transaction → system migrations → boot rebuild
 → pending-reboot → boot/session health → committed
```

每阶段写本机 root-owned journal、目标世代与完成证据；下载完成、包事务完成和升级健康是三个不同事件。pacman 并非断电原子的 A/B 部署系统，不能把 package transaction 成功等同整机可回滚。

## 3. 预检和保护

- 单一升级锁，同时尊重 pacman 自己的锁；检查电源、根/boot/ESP/快照空间、时钟、签名、源一致性与待合并 `.pacnew`。
- 获取并验签全组包，锁定目标世代；下载期断网可重试，写入期不能声称可随时取消。
- 更新会改 boot/驱动或不可逆数据前，准备并验证恢复集。策略要求必须有恢复点时，快照失败直接停止，不弹一个绿色成功标题继续。
- 防休眠/关机 inhibition 仅覆盖必要阶段，并保证失败后释放；不能借此阻止紧急恢复。
- keyring 轮换按旧可信链先引入新钥，再执行匹配的完整更新；不要把上游针对 keyring 的特殊维护步骤抽出来变成常规部分升级。

## 4. 迁移按作用域分层

| 类型 | 执行身份 | 规则 |
|---|---|---|
| 系统迁移 | root | 处理 `/etc`、units、boot；不依赖交互会话 |
| 用户迁移 | 登录用户 | 处理该用户配置；无登录时延迟，不遍历 home 强改 |
| 应用数据迁移 | 数据所有者 | 明确 schema、备份、一致性与降级兼容 |

每个迁移具备唯一 ID、前置版本、重复执行行为、失败退出、恢复说明；**成功后**记录 applied。写配置采用临时文件→校验→同文件系统原子替换，保留权限/所有者；不要用原子替换一词掩盖多个文件间并非事务。

提供 fresh-install 基线，避免新用户执行所有历史迁移；无图形会话/SSH 更新不能让系统迁移死等通知服务。包重命名优先用元数据表达，迁移只处理无法由包管理器表达的状态。

ALPM hooks 用于局部、确定的工作，不做联网向导、再次 pacman 或长时间图形交互。hook 失败可能发生在包已更新之后，需保留 degraded 状态并给恢复步骤，不能假称包事务自动撤销。

## 5. 可变系统与 A/B 路线不要混淆

- pacman 可变根：备份/快照＋完整升级＋显式恢复，迁移和 boot 的一致性由发行版编排。
- A/B/镜像：构建完整部署、验证签名、写非活动槽、切入口、健康确认后提交；`/var`、用户数据与 schema 单独设计。
- `systemd-sysupdate` 是可采用的镜像更新工具，不会自动把任意 Arch 桌面改造成原子系统；需要 transfer 配置、分区/文件资源及完整启动/回退设计。
- 可写 overlay、只读 root、system extensions 等不同方案必须明确包所有权和持久化位置，不能让用户在不可变层运行 pacman 后期待跨镜像保留。

## 6. Omarchy 的实现与不能照搬之处

`bin/omarchy-update` 编排快照、抑制休眠、keyring、系统包、迁移、服务、工具链/AUR 与 boot 操作。`docs/update-process.md` 可跟踪分阶段责任。

固定取样中：快照失败可警告后继续，AUR 不可达可跳过；末尾 `bin/omarchy-update-boot` 经 dispatcher 调用，而非 Apple 平台可能是 no-op。**这些都是源码行为，不是本 skill 建议的生产发布门禁**。本发行版必须定义失败是否允许继续，并把“部分完成/未验证”显示给用户。

`967bbdd73` 把区域包源渲染接回 refresh 流程：首次安装的镜像设置若在更新时丢失，会造成维护路径漂移。区域源、keyring、通道与用户 hook 要共同测试。

## 7. 失败分支与故障注入

| 触发条件 | 一线处理 | 仍失败 |
|---|---|---|
| 镜像不同步/签名坏 | 换已受信任且同世代的镜像，校时/keyring | 停止，不降低签名等级 |
| 包事务中断 | 查真实 pacman 日志与文件/数据库一致性 | 可信 live/chroot 修复或恢复匹配恢复集 |
| 系统迁移失败 | 不记完成；允许幂等重试并显示 degraded | 恢复配置/系统；不可逆数据按专门方案恢复 |
| 新系统无法启动 | 选择已知良好入口/恢复集 | 从可信救援介质恢复，不仅回退仓库 URL |
| 发现安全回归 | 停止推广，撤回通道并通知用户 | 已安装客户端执行显式修复/恢复，不能假装指针回退已修复 |

测试在下载、包提交、迁移、boot 重建、首次重启各阶段断电/断网、空间不足、损坏数据库和吊销密钥。对正在写数据的测试使用一次性磁盘/VM，不对用户当前系统注入故障。

依据：[pacman 维护规则](sources.md#基础与包)、[sysupdate 与启动评估](sources.md#引导与更新)。
