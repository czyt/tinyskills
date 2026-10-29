# 场景实测记录

日期：2026-10-29。这里保存可复核的输出摘录与观察，不把 LLM 单次回答当成功率。完整测试输入见[测试集](../test-prompts.json)，RED 观察见[编写清单](authoring-checklist.md)。

## 方法与边界

- RED：一个新上下文 agent 在没有候选 skill/源码/工具时回答前三个相同用户 prompt。
- GREEN：两个新上下文 agent 读取候选主文件并自行检索专题，分别回答 A/B 与 C/D；禁止读取本评估目录和 expected 字段。
- A 的初次 GREEN 仍省略独立 rootfs 工厂产物，故增加结构化交付栏并用新上下文重测同一个原始 prompt。
- D 是用户追加 Apple 要求后的检索测试，没有无 skill 对照，不声称测得 Apple 能力的量化增益。
- 所有场景只产出方案，没有构建 ISO、修改磁盘、运行更新/恢复或测试实体硬件。前三个 RED 已有很好的安全基础；不把这些能力归功于新 skill。

## 初次 GREEN 的真实观察

| 场景 | 输出原文摘录 | 观察 |
|---|---|---|
| A / first-release | “构建/live/target 三份源配置分别验收”；“首次开机生成设备密钥，首次登录初始化用户，失败持久化续跑” | 新增去身份化、初始化与来源边界；仍用 ISO 原型概括 rootfs，不能记满通过 |
| B / Omarchy 分支 | “源码地图取样为 `84782475a`”；“`omarchy-apply-system` 只是目标配置入口，包配方还在外仓” | 成功检索固定版本/具体入口；有 KDE 会话隔离、NVIDIA 匹配、离线依赖闭包与 ESP 保护 |
| C / 更新恢复压力 | “快照 ID、子卷及可读性，失败即停”；“撤回仓库指针不会修复已升级机器” | 正确拒绝部分升级/跳过签名，明确恢复集、keyring 轮换、不可逆数据和 Windows 边界 |
| D / Apple | “`pacman.sh:9` 的 `SigLevel = Never` 是不能照抄的安全缺口”；“代码存在接口不等于普通 ISO 已适配” | 区分三类 Mac，检索具体 Apple 包/文件及三条历史提交；明确外部实现与真机未验证 |

两个 GREEN agent 实际读取了主文件及各自相关专题；D 还交叉读取 Omarchy 当前源码与三条提交 diff。这里仅引用结论，不把 agent 的“已读”当真机支持证据。

## 核验中暴露并修正的问题

1. 首次从零方案的 rootfs 产物被略写：主文件输出契约增加四个固定交付栏。
2. 外部仓库名误写为 `CachyOS-ISO`：核对官方项目后修正为 `CachyOS-Live-ISO`，并明确资料核验深度。
3. 从 systemd 一手文档补入 D-Bus machine-id 可能回用旧 ID 的边界。
4. 从 Asahi 指南补入 per-OS ESP 的平台区别，不把 PC 共用 ESP 推广给 Apple Silicon。
5. 从官方工程说明补充 EndeavourOS 在线/离线选择与 CachyOS live/target 内核、ESP 容量的历史对照，不泛化为永久默认。
6. 第一轮独立 paired 评审指出补充资料链接仍有误：不存在的 DEVELOPMENT.md、缺 `.md` 的 CHANGELOG，以及失效的 Hyprland wiki 子路径。随后从官方仓库页面实际跟链读取正文，分别改为 EndeavourOS 开发站、CHANGELOG.md 和 UWSM 官方 README；不把搜索命中当正文核验。

## 静态与无副作用验证

已执行：

- `quick_validate.py`：frontmatter、名称、description 与 Markdown 基础规则通过。
- `python -m json.tool`：测试集 JSON 可解析。
- `bash -n`：完整实验脚本以及四个 Markdown shell 示例语法通过。
- `bash .../first-iso.sh --help`：真实帮助入口返回成功。
- 五种缺参数/缺确认/未知参数入口返回 2，且未创建输出目录。
- 当前非 root 用户下显式 build 请求在写入前被拒绝；未进入构建。
- 初查 35 个本地链接/锚点与地图内 47 个源码路径；最终扩大到 38 个本地链接/锚点及三个源码专题中的 61 个去重路径，均通过存在性检查。
- Omarchy HEAD 保持取样 SHA，工作区无修改；现有 `.sisyphus/` 未触碰。

这些验证不是对本机缺失的 `mkarchiso` 的模拟测试，也没有用 stub 冒充 ISO 构建；ISO、QML 图形会话、实体驱动与恢复仍标记未验证。

## A 的新上下文回归

同一个原始 prompt、同样约 400–600 字约束，新 agent 返回四个交付栏，包含：

> 锁定包表，经干净构建、pacstrap 生成独立 live/target 树；清除 machine-id、私钥及凭证；双实例验身份独立。

其他栏分别列出 archiso/mkarchiso→ISO、Calamares→target 部署、first-boot/first-login→升级/恢复；同时声明写盘确认、验签失败停止、没有启动/恢复证据不能发布。该样本中原先略写的 rootfs 部分已补齐，不外推成所有任务都会遵守的成功率。

## 独立 Apple 技术复核

复核者对照实际 Omarchy 固定 SHA 与三条 Apple 提交，未发现阻断性事实错误；没有把 T2 关闭验签作为推荐、没有混淆 keyslot 与 volume key、没有把外部包或 fixture 当完整底层实现。

三条具体反馈均已纳入：

- `luks_rekey_retire()` 会删除 owner 之外全部 keyslots；新增警示，不能复制到有恢复/管理员/TPM 密钥的已有磁盘。
- baseline 保留的是已有 HOOKS 数组，后续 drop-in 仍可能修改；不笼统说整套 initramfs 保持不变。
- NVMe 修补针对 suspend/resume，不是 hibernation；术语分开。

## Darwin paired 评审

第一轮巡检的原票保留：两名认为修订版 better/slight，一名 worse/clear；三名都指出资源深链错误，runtime-neutral gate 均通过，实际效果维度未获得配对输出证据者均写 unknown。**不因 2:1 多数就忽略可核验的错误引用。**修正后冻结最终候选，再交同三名独立评审。

最终候选摘要（路径＋文件 SHA-256 的稳定聚合，不含 evaluations）：`ae83936e97216d8a229c5d2471ad626e5f740a77b320dbc78ea54b79f96b9716`。

最终三票均为 **better / slight**，runtime gate 均为 pass，原链接阻断均解除；评审确认引用正文支持所述在线/离线、内核/ESP、会话环境结论，未发现新的技术阻断。实际应用效果维度都保持 unknown：评审没有收到新旧完整应用输出，不能自行模拟后假称实测。

候选聚合摘要由主 agent 的实际校验命令核对；其中一名评审明确没有独立核对聚合算法，本记录不把三票描述成三次独立密码学认证。外部滚动网页未全部固定 commit，实施时仍须按来源索引锁定实际输入。

新 skill 没有可比较的旧质量总分，因此不发布伪造的“分数上涨”；paired 仅判断文字/资源修订，不替代前面的独立场景测试与真机验证。两轮后停止继续微调，交付用户审阅。
