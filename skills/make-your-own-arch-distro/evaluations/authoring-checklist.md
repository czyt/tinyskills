# 编写与验证记录

日期：2026-10-29。范围：新建一个中文、跨 runtime 的工程参考 skill；不构建真实发行版、不修改 Omarchy、不执行分区/安装命令，不创建分支或提交。

## RED：无 skill 的实测

- [x] 创建典型场景、桌面分支场景、时间压力下的更新恢复场景。
- [x] 新上下文子 agent 在没有候选 skill、没有源码、没有工具的条件下回答前三个原始 prompt。
- [x] 逐条人工阅读结果；安全基础表现良好，不把已有能力虚报成 skill 收益。
- [x] 确认参考资料缺口：可执行 rootfs 工厂、去身份化与延迟初始化、真实源码/版本/提交定位。

原始片段与观察：

| 场景 | 原始回答摘录 | 已有能力 | 未满足的教学目标 |
|---|---|---|---|
| first-release | “使用 `archiso` 的 `releng` 配置” | 镜像、签名、仓库世代、VM/硬件测试 | 未解释 rootfs 与 live/target 的关系、去身份化、first-boot/first-login |
| omarchy-not-the-whole-distro | “Omarchy 配置不能替代启动镜像、分区安装器、可信仓库” | 桌面会话隔离、NVIDIA 匹配、离线依赖闭包、ESP 保护 | 没有具体源码/外部仓库边界；不知道当前 Omarchy 的包拆分和配置版本 |
| update-recovery-pressure | “回退仓库指针不会回滚已升级客户端” | 拒绝部分升级/跳过签名，识别 pacman 数据库、ESP、非递归快照 | 未给初始化/密钥轮换状态机，未涉及克隆镜像密钥和启动健康判据 |

这些是**参考型 skill 的信息与检索缺口**，不是“agent 受压后违反纪律”。采用有输入输出的步骤、专题路由、来源索引和源码讲解，不堆砌惩罚性禁令。纯参考内容不做措辞诱导的五次 micro-test。Apple 场景是用户追加要求后的独立检索回归，不伪称已有无 skill 对照。

## GREEN：交付检查

- [x] 名称与用户指定一致；frontmatter 只有标准字段，description 只描述触发条件。
- [x] 主文件精简，专题按需加载，所有本地相对链接可达。
- [x] 提供完整而非伪代码式的实验示例；语法和无副作用入口检查。没有实际执行 ISO 构建。
- [x] rootfs、驱动、桌面、仓库、ISO、安装器、初始化、升级、恢复、引导、多架构与退役均有交付物/门禁。
- [x] Apple 专题独立，Intel/T2/Apple Silicon 分开，源码与外部支持边界可追溯。
- [x] 读过关键 Git diff，不凭提交标题推断结论。
- [x] 运行前三个相同 prompt 的带 skill 对照，加测 Apple 检索；对首次 rootfs 略写做新上下文回归。
- [x] Apple 独立技术复核及三名 paired 评审检查资料真实性、遗漏、风险和 runtime 中立性。
- [x] 校验 frontmatter、JSON、Markdown 链接、shell 语法、六种拒绝入口；不执行分区/安装/升级。

## REFACTOR / Darwin

- [x] 修正检索遗漏、源码语义和失效引用；独立 paired 比较最终 3:0 better/slight，不用跨 judge 分数差宣称收益。
- [x] 第一轮即使 2:1 better，也因实证坏链阻断交付；修正后冻结候选再评，不抹去原来的 worse 票。
- [x] 分开报告文档/agent 行为验证与 ISO 构建/真机验证；后者本任务不执行。
- [x] 准备交付用户审阅；未擅自 commit/push、建分支或修改全局 skill。用户尚未审阅，不虚构批准。

统计仅描述本次样本，不构成成功率或生产可靠性证明。原始场景见 `../test-prompts.json`，结果见 [scenario-results.md](scenario-results.md)，机器可读日志见 `results.tsv`。这是新 skill 的编写与验证，不冒充一次经过用户逐阶段批准的既有 skill 自动优化/发布流程。
