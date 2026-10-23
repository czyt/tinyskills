[Skip to content](https://github.com/arcships/rutis#start-of-content)

You signed in with another tab or window. [Reload](https://github.com/arcships/rutis) to refresh your session.You signed out in another tab or window. [Reload](https://github.com/arcships/rutis) to refresh your session.You switched accounts on another tab or window. [Reload](https://github.com/arcships/rutis) to refresh your session.Dismiss alert

{{ message }}

main

[**360** Branches](https://github.com/arcships/rutis/branches) [**25** Tags](https://github.com/arcships/rutis/tags)

[Go to Branches page](https://github.com/arcships/rutis/branches)[Go to Tags page](https://github.com/arcships/rutis/tags)

Go to file

Code

Open more actions menu

## Latest commit

[![eric8810](https://avatars.githubusercontent.com/u/756579?v=4&size=40)](https://github.com/eric8810)[eric8810](https://github.com/arcships/rutis/commits?author=eric8810)

[Merge pull request](https://github.com/arcships/rutis/commit/bf1e74579633c4d78bd779aa7a46a46e2c65eff4) [#595](https://github.com/arcships/rutis/pull/595) [from arcships/ci/no-debug-info](https://github.com/arcships/rutis/commit/bf1e74579633c4d78bd779aa7a46a46e2c65eff4)

Open commit details

6 minutes agoOct 23, 2026

[bf1e745](https://github.com/arcships/rutis/commit/bf1e74579633c4d78bd779aa7a46a46e2c65eff4) · 6 minutes agoOct 23, 2026

## History

[1,809 Commits](https://github.com/arcships/rutis/commits/main/)

Open commit details

[View commit history for this file.](https://github.com/arcships/rutis/commits/main/) 1,809 Commits

## Folders and files

| Name | Name | Last commit message | Last commit date |
| --- | --- | --- | --- |
| [.agents/skills](https://github.com/arcships/rutis/tree/main/.agents/skills "This path skips through empty directories") | [.agents/skills](https://github.com/arcships/rutis/tree/main/.agents/skills "This path skips through empty directories") | [fix(events): Node 不再在同步等待期间就地执行监听器调用；快速路径上的 emit 排在被扣住的同名调用之后；等待图记入口](https://github.com/arcships/rutis/commit/a2748bf3272932ec87228c2b4e9e71228d900443 "fix(events): Node 不再在同步等待期间就地执行监听器调用；快速路径上的 emit 排在被扣住的同名调用之后；等待图记入口  - Node 保持不可重入：emit 方式的 events.call 在同步等待期间照旧被扣住；会话新增 behind，本进程快速路径上的同名 emit 排在被扣住的调用之后，按帧的顺序执行（§5.5） - 等待图：没有调用方同步等待、进入 sync-stack 运行时的调用记为入口，栈顺序对它成立；修复可重入的 Python / Bun 把监听器压在等待上面、回调不可重入运行时时查不出的卡死 - TLA+ 模型加入 Rust 的投递（入口），新增 current-posts 等四个配置 - 测试：Node 会话单元测试、waits 单元测试、sync_cycles 集成测试（Python / Node / Bun） - 文档：§5.5 撤回 Node 对监听器可重入的说法；迁移说明、运行时约定、多语言设计 §9、保证表") | 2 days agoOct 21, 2026 |
| [.cargo](https://github.com/arcships/rutis/tree/main/.cargo ".cargo") | [.cargo](https://github.com/arcships/rutis/tree/main/.cargo ".cargo") | [feat: add Linux dylib SDK and guarded plugin loader](https://github.com/arcships/rutis/commit/6457fcba4564e581d88fd524c9b5079c22b2dc70 "feat: add Linux dylib SDK and guarded plugin loader") | last monthSep 25, 2026 |
| [.github](https://github.com/arcships/rutis/tree/main/.github ".github") | [.github](https://github.com/arcships/rutis/tree/main/.github ".github") | [ci: dev/test 构建关闭 debug info](https://github.com/arcships/rutis/commit/fcc110708e9753f8fa8cd74c7f6e9fa867f29d9f "ci: dev/test 构建关闭 debug info  CI 只运行测试和检查，不读 backtrace；dev/test profile 不生成 debug info，缩小 target 目录和 rust-cache 归档并缩短链接。release 已在 Cargo.toml 设 debug = 0，不受影响。") | 1 hour agoOct 23, 2026 |
| [assets/logo](https://github.com/arcships/rutis/tree/main/assets/logo "This path skips through empty directories") | [assets/logo](https://github.com/arcships/rutis/tree/main/assets/logo "This path skips through empty directories") | [chore(brand): 从仓库移除随](https://github.com/arcships/rutis/commit/b73378ff27325e3463d0fe78ec9a6408210f6b6f "chore(brand): 从仓库移除随 #375(5bcc047) 误入的 logo 宣传图与探索稿  banner/、brand/preview/ 与候选探索稿是本地素材，不在仓库跟踪范围内； 那次 CI 提交用 git add -A 把它们一并带进了 main。这里 git rm --cached 只移除仓库副本，本地文件保留，路径已由 .gitignore 排除。") [#375](https://github.com/arcships/rutis/pull/375) [(](https://github.com/arcships/rutis/commit/b73378ff27325e3463d0fe78ec9a6408210f6b6f "chore(brand): 从仓库移除随 #375(5bcc047) 误入的 logo 宣传图与探索稿  banner/、brand/preview/ 与候选探索稿是本地素材，不在仓库跟踪范围内； 那次 CI 提交用 git add -A 把它们一并带进了 main。这里 git rm --cached 只移除仓库副本，本地文件保留，路径已由 .gitignore 排除。") [`5bcc047`](https://github.com/arcships/rutis/commit/5bcc0475b66b6fc59650b4c845cb64efd0cac917) [) 误入的 logo 宣传图与探索稿](https://github.com/arcships/rutis/commit/b73378ff27325e3463d0fe78ec9a6408210f6b6f "chore(brand): 从仓库移除随 #375(5bcc047) 误入的 logo 宣传图与探索稿  banner/、brand/preview/ 与候选探索稿是本地素材，不在仓库跟踪范围内； 那次 CI 提交用 git add -A 把它们一并带进了 main。这里 git rm --cached 只移除仓库副本，本地文件保留，路径已由 .gitignore 排除。") | last weekOct 14, 2026 |
| [bun/rutis-bun](https://github.com/arcships/rutis/tree/main/bun/rutis-bun "This path skips through empty directories") | [bun/rutis-bun](https://github.com/arcships/rutis/tree/main/bun/rutis-bun "This path skips through empty directories") | [fix(bun): 拨出在 Bun 1.4.4 上的升级被拒与证书被拒](https://github.com/arcships/rutis/commit/effe3f4e50a16446af03313654b15866355bf39c "fix(bun): 拨出在 Bun 1.4.4 上的升级被拒与证书被拒  Bun 1.4.4 的 ws 客户端在有 unexpected-response 监听时不再自己关闭连接 （与 npm ws 一致），拨出要等 10 秒握手时限才失败；证书被拒改为 Node 式 的错误码加关闭码 1006，不再是 1015，被归为 retryable。  - 读完拒绝的响应体就结束连接并报错，同 Node 运行时 - 错误码指向证书（CERT/SIGNATURE/ALTNAME/ISSUER）时归为 auth-rejected；   1015 仍然认") | 18 hours agoOct 22, 2026 |
| [crates](https://github.com/arcships/rutis/tree/main/crates "crates") | [crates](https://github.com/arcships/rutis/tree/main/crates "crates") | [Merge pull request](https://github.com/arcships/rutis/commit/db617348dc0f1d04eb074e8b905f3b1f492100fd "Merge pull request #586 from arcships/fix/sdk-bundle-duplicate-names  fix(xtask): pack-sdk-bundle 按 crate 名只复制一次") [#586](https://github.com/arcships/rutis/pull/586) [from arcships/fix/sdk-bundle-duplicate-names](https://github.com/arcships/rutis/commit/db617348dc0f1d04eb074e8b905f3b1f492100fd "Merge pull request #586 from arcships/fix/sdk-bundle-duplicate-names  fix(xtask): pack-sdk-bundle 按 crate 名只复制一次") | 2 hours agoOct 23, 2026 |
| [docs](https://github.com/arcships/rutis/tree/main/docs "docs") | [docs](https://github.com/arcships/rutis/tree/main/docs "docs") | [fix(node): 带 inject 的行以其插件 apply 的错误失败 (](https://github.com/arcships/rutis/commit/b764588d7840b3fe1dcf51c1704c509085bd9d59 "fix(node): 带 inject 的行以其插件 apply 的错误失败 (#584)  Cordis 运行时把带行级 inject 的行放在门控 fiber 后运行，插件在门控里自己的 fiber 中运行；loadRow 只等外层门控 fiber，内层 apply 失败不会让行失败。 现在门控生效后也等内层 fiber，行以插件的错误失败，与不带 inject 的行一致。 bridge 的 host 功能（代对端托管插件）有同样的门控，一并修复。  测试：Node 运行时 rows-gated.test.mjs；rutis-loader runtime_rows a_gated_row_fails_with_its_plugins_error；事件一致性新用例 rutis/row-failed-gated（每个语言列）；节点一致性新增 apply 失败的装载 （带与不带 inject）。") [#584](https://github.com/arcships/rutis/issues/584) [)](https://github.com/arcships/rutis/commit/b764588d7840b3fe1dcf51c1704c509085bd9d59 "fix(node): 带 inject 的行以其插件 apply 的错误失败 (#584)  Cordis 运行时把带行级 inject 的行放在门控 fiber 后运行，插件在门控里自己的 fiber 中运行；loadRow 只等外层门控 fiber，内层 apply 失败不会让行失败。 现在门控生效后也等内层 fiber，行以插件的错误失败，与不带 inject 的行一致。 bridge 的 host 功能（代对端托管插件）有同样的门控，一并修复。  测试：Node 运行时 rows-gated.test.mjs；rutis-loader runtime_rows a_gated_row_fails_with_its_plugins_error；事件一致性新用例 rutis/row-failed-gated（每个语言列）；节点一致性新增 apply 失败的装载 （带与不带 inject）。") | 4 hours agoOct 23, 2026 |
| [examples](https://github.com/arcships/rutis/tree/main/examples "examples") | [examples](https://github.com/arcships/rutis/tree/main/examples "examples") | [feat: Rust 服务在类型上标注 #\[rutis::service\] 即对外，不再需要 build.rs 清单（](https://github.com/arcships/rutis/commit/044d2ea02b50f2312b0db53216930f1ded69fc2d "feat: Rust 服务在类型上标注 #[rutis::service] 即对外，不再需要 build.rs 清单（#510）") [#510](https://github.com/arcships/rutis/issues/510) [）](https://github.com/arcships/rutis/commit/044d2ea02b50f2312b0db53216930f1ded69fc2d "feat: Rust 服务在类型上标注 #[rutis::service] 即对外，不再需要 build.rs 清单（#510）") | 2 days agoOct 21, 2026 |
| [fuzz](https://github.com/arcships/rutis/tree/main/fuzz "fuzz") | [fuzz](https://github.com/arcships/rutis/tree/main/fuzz "fuzz") | [release: 0.13.0](https://github.com/arcships/rutis/commit/15d9c0f9c17257ca3de830bc5726c6f315521fbb "release: 0.13.0  按 docs/release.md 第 1 步，从 0.12.1 升到 0.13.0（统一事件，#464）：列车 crate 与相互依赖、rutis-cli/agent/dev 的依赖、npm/Bun/Python/Go 包、 rutis-host 的运行时与平台包依赖、次版本范围 0.12 → 0.13；持久化样本 0.13.0（节点行用 0.13 的事件 export/import 写法）；发布说明定稿； docs/release.md 加 0.13.0 一节；fuzz/Cargo.lock 补上 rutis 对 serde 的依赖。") | 4 days agoOct 19, 2026 |
| [go/rutis](https://github.com/arcships/rutis/tree/main/go/rutis "This path skips through empty directories") | [go/rutis](https://github.com/arcships/rutis/tree/main/go/rutis "This path skips through empty directories") | [fix(swift,go): 放开的过滤器失败也不报告；Go 的 On 在已卸载的行上报告而不 panic](https://github.com/arcships/rutis/commit/7d7460cc07538e171c4c18a37c2cb69072b502be "fix(swift,go): 放开的过滤器失败也不报告；Go 的 On 在已卸载的行上报告而不 panic") | 2 days agoOct 21, 2026 |
| [kotlin](https://github.com/arcships/rutis/tree/main/kotlin "kotlin") | [kotlin](https://github.com/arcships/rutis/tree/main/kotlin "kotlin") | [fix(kotlin): a failing cleanup does not stop the other rows' cleanups (](https://github.com/arcships/rutis/commit/2b613fe2c083331f288192167b758df83d518e41 "fix(kotlin): a failing cleanup does not stop the other rows' cleanups (#544)  dispose gave up every row after one whose cleanup threw. Only the deadline gives up now; a failure is reported and the other rows unload. Tests: stuck listeners in several rows bounded by one budget, a throwing cleanup in one row, and a late effect neither registered nor run.") […](https://github.com/arcships/rutis/issues/544) | yesterdayOct 22, 2026 |
| [node](https://github.com/arcships/rutis/tree/main/node "node") | [node](https://github.com/arcships/rutis/tree/main/node "node") | [fix(node): 带 inject 的行以其插件 apply 的错误失败 (](https://github.com/arcships/rutis/commit/b764588d7840b3fe1dcf51c1704c509085bd9d59 "fix(node): 带 inject 的行以其插件 apply 的错误失败 (#584)  Cordis 运行时把带行级 inject 的行放在门控 fiber 后运行，插件在门控里自己的 fiber 中运行；loadRow 只等外层门控 fiber，内层 apply 失败不会让行失败。 现在门控生效后也等内层 fiber，行以插件的错误失败，与不带 inject 的行一致。 bridge 的 host 功能（代对端托管插件）有同样的门控，一并修复。  测试：Node 运行时 rows-gated.test.mjs；rutis-loader runtime_rows a_gated_row_fails_with_its_plugins_error；事件一致性新用例 rutis/row-failed-gated（每个语言列）；节点一致性新增 apply 失败的装载 （带与不带 inject）。") [#584](https://github.com/arcships/rutis/issues/584) [)](https://github.com/arcships/rutis/commit/b764588d7840b3fe1dcf51c1704c509085bd9d59 "fix(node): 带 inject 的行以其插件 apply 的错误失败 (#584)  Cordis 运行时把带行级 inject 的行放在门控 fiber 后运行，插件在门控里自己的 fiber 中运行；loadRow 只等外层门控 fiber，内层 apply 失败不会让行失败。 现在门控生效后也等内层 fiber，行以插件的错误失败，与不带 inject 的行一致。 bridge 的 host 功能（代对端托管插件）有同样的门控，一并修复。  测试：Node 运行时 rows-gated.test.mjs；rutis-loader runtime_rows a_gated_row_fails_with_its_plugins_error；事件一致性新用例 rutis/row-failed-gated（每个语言列）；节点一致性新增 apply 失败的装载 （带与不带 inject）。") | 4 hours agoOct 23, 2026 |
| [python/rutis](https://github.com/arcships/rutis/tree/main/python/rutis "This path skips through empty directories") | [python/rutis](https://github.com/arcships/rutis/tree/main/python/rutis "This path skips through empty directories") | [test(events): let disconnect/bail-in-flight's listener wait until Y i…](https://github.com/arcships/rutis/commit/fe0800539389a27c3214b2183946d5741fa8b67c "test(events): let disconnect/bail-in-flight's listener wait until Y is killed  The case's sync listener at Y slept 3000 ms and then returned \"late\"; the test kills Y during that sleep. On a loaded runner the kill landed after it, and the bail returned \"late\" instead of throwing BindingError (CI run 39723620868, X=cordis and X=bun).  The listener now does {\"waits\": true}: it never returns on its own. A sync listener that cannot be woken blocks its thread until its process ends: the Node (Cordis, leaf, runner), Bun and Python fixtures do that now; Go, Kotlin and Swift already wait for cancellation, which a sync listener's dispatch waits on too. The contract's waits row says so.  With Y's kill delayed 3.5 s, the old case failed in every placement and the new one passed with X and Y in all seven languages.") | yesterdayOct 22, 2026 |
| [scripts](https://github.com/arcships/rutis/tree/main/scripts "scripts") | [scripts](https://github.com/arcships/rutis/tree/main/scripts "scripts") | [fix(service): dylib 插件经 rutis\_sdk::rutis::service 拿到标注、rutis-macros 进…](https://github.com/arcships/rutis/commit/f2ac569a16e1d88dc5cbe1854e078e6c434f69d3 "fix(service): dylib 插件经 rutis_sdk::rutis::service 拿到标注、rutis-macros 进发布列车、重名在提供前拒绝；补验收测试与文档（#510）  - 宏不再读 Cargo.toml 猜路径：rutis_sdk::rutis 改为模块，其中的 service 是生成 ::rutis_sdk::rutis 的同一个宏，对着 sdk-bundle 构建、没写依赖的插件也能编译（dylib-linux-sdk-bundle、dylib-macos、dylib-windows） - scripts/train.mjs 把 rutis-macros 排在 rutis 之前，release.yml、release.md 写明首次发布（release-dry-run） - provide 先按名字提供再登记原生服务：重名时什么都不提供；带限定名的绑定不按名字对外 - R5 的错误都提示 #[service(skip)]，单元测试检查错误指到那一行，rutis 的文档测试检查编译失败与 skip 后通过 - 测试：Node/Python/Go 的行经 &Ctx 拿到调用方行；dylib 换代时按名字依赖的插件重载、卸载后不再提供；标注与 build.rs 列出写出相同的声明 - 文档：迁移说明并入 0.15，Rust 宿主指南、设计、承诺表与 agent skills 更新") | 2 days agoOct 21, 2026 |
| [specs](https://github.com/arcships/rutis/tree/main/specs "specs") | [specs](https://github.com/arcships/rutis/tree/main/specs "specs") | [fix(bridge): 等待图里入口是调用链的边界，任何运行时都记；检查改为近线性；模型按发出方的调用链投递](https://github.com/arcships/rutis/commit/6488c8c004f5156513c34f86a4d14cd59a3b7133 "fix(bridge): 等待图里入口是调用链的边界，任何运行时都记；检查改为近线性；模型按发出方的调用链投递  - 入口（没有调用方同步等待的调用：events.call、异步调用）不论目标是否单栈都记，作为调用链的边界：链边 c → d 只在 d 的链里 c 与 d 之间没有入口时成立。修复 events.call 带发出方调用链时的误报 SyncWaitCycle - 等待表按调用 id 索引；started 一次算出；栈顺序只连到下一个已开始的调用；未开始的入口不连“放到一边”的边。检查与调用数、调用链长度成近线性 - TLA+：发出由正在执行的活动做，投递带发出方的调用链；真实图与 Rust 的图都以入口为链的边界 - 测试：an_emitters_chain_is_not_waited_for、a_listener_with_its_emitters_chain_on_top_of_a_wait、the_check_is_near_linear_in_entries - 文档：requirements-protocol-plugins 补 Node 的例外；多语言设计 §9、模型 README、保证表") | 2 days agoOct 21, 2026 |
| [swift](https://github.com/arcships/rutis/tree/main/swift "swift") | [swift](https://github.com/arcships/rutis/tree/main/swift "swift") | [Merge pull request](https://github.com/arcships/rutis/commit/bbe0975525a4a8990a2b046c6279bb88dd39d8c4 "Merge pull request #554 from arcships/fix/issue-542-swift-remote  fix(swift): close a dialed connection and push filtered emits in order") [#554](https://github.com/arcships/rutis/pull/554) [from arcships/fix/issue-542-swift-remote](https://github.com/arcships/rutis/commit/bbe0975525a4a8990a2b046c6279bb88dd39d8c4 "Merge pull request #554 from arcships/fix/issue-542-swift-remote  fix(swift): close a dialed connection and push filtered emits in order") | yesterdayOct 22, 2026 |
| [tests](https://github.com/arcships/rutis/tree/main/tests "tests") | [tests](https://github.com/arcships/rutis/tree/main/tests "tests") | [Merge pull request](https://github.com/arcships/rutis/commit/8005f75db43c546c807f8c9ff47d92e1d1e7eb02 "Merge pull request #581 from arcships/fix/issue-568-fixture-ready  test(e2e): tenants fixture 等全局行启动后再打印 ready") [#581](https://github.com/arcships/rutis/pull/581) [from arcships/fix/issue-568-fixture-ready](https://github.com/arcships/rutis/commit/8005f75db43c546c807f8c9ff47d92e1d1e7eb02 "Merge pull request #581 from arcships/fix/issue-568-fixture-ready  test(e2e): tenants fixture 等全局行启动后再打印 ready") | 4 hours agoOct 23, 2026 |
| [tools](https://github.com/arcships/rutis/tree/main/tools "tools") | [tools](https://github.com/arcships/rutis/tree/main/tools "tools") | [test: 防挂死上限随 RUTIS\_TEST\_TIME\_SCALE 放长；本地运行时问候时限改为 30 秒](https://github.com/arcships/rutis/commit/94c41a46879bcc4fadc308f987b01bfe3f7d613a "test: 防挂死上限随 RUTIS_TEST_TIME_SCALE 放长；本地运行时问候时限改为 30 秒  - rutis-test-support：所有上限（HANG_GUARD、Guard、within、eventually、   recv_within）乘以 RUTIS_TEST_TIME_SCALE（默认 1），新增 scaled()、   Guard::limit()；测试里直接用 HANG_GUARD / COLD.0 的等待改为 scaled /   limit() - ci.yml：自托管 Linux runner 的 start 步骤传入 LINUX_TEST_TIME_SCALE   （默认 3），tools/ci-self-hosted.sh 写进任务环境 - LinkConfig::local_runtime：问候时限从 10 秒改为 30 秒（从进程启动算起，   包含解释器启动；进程退出会立即发现，这个时限只约束活着却不说话的进程） - docs/ci.md、docs/ci.en.md §11") | 18 hours agoOct 22, 2026 |
| [.gitignore](https://github.com/arcships/rutis/blob/main/.gitignore ".gitignore") | [.gitignore](https://github.com/arcships/rutis/blob/main/.gitignore ".gitignore") | [feat(swift): Swift SDK 的会话层与值（](https://github.com/arcships/rutis/commit/52096854bed97e963a1bffb3ae5f6dca6906baf2 "feat(swift): Swift SDK 的会话层与值（#386）  仓库根 Package.swift（macOS 14 / iOS 17，库 Rutis 只依赖 Foundation）。 swift/rutis/Sources/Rutis： - 会话：compat 2 与 endpoint 3 两种握手，能力 signals、sync-wait、   reentrant-sync、events-v2、十个 value-<tag>；一个读线程解析帧，每个   进来的调用一个 Task，调用链放 @TaskLocal；引用、future、信号、取消、   release 计数、64 层深度、畸形帧结束会话 - 通道：fd、unix、tcp（先发 RUTIS_CHANNEL_TOKEN），按行分帧、16 MiB 上限 - 值：自己的 JSON（数字保留原文）、十种带标记的值（Rutis.DateTime /   CalendarDate / TimeOfDay / BigInt，Date、Data、Decimal、UUID、   Dictionary、Set 原生）、超界整数自动 bigint、Map 键与 Set 元素规则 - 编解码：自己的 Encoder / Decoder（不用 JSONEncoder），Any 解码为原生值 - 错误：RutisError，name / message / code / data 与错误图两个方向  一致性：RutisSessionFixture 过 runtime_conformance（Unix socket 与 loopback、畸形帧）和 value_roundtrip（数据、带标记的值、深度、release 计数）；rutis-bridge 加 feature swift。CI 加 runtimes-swift（自托管 macOS），train.mjs 加 Swift 版本文件。") [#386](https://github.com/arcships/rutis/issues/386) [）](https://github.com/arcships/rutis/commit/52096854bed97e963a1bffb3ae5f6dca6906baf2 "feat(swift): Swift SDK 的会话层与值（#386）  仓库根 Package.swift（macOS 14 / iOS 17，库 Rutis 只依赖 Foundation）。 swift/rutis/Sources/Rutis： - 会话：compat 2 与 endpoint 3 两种握手，能力 signals、sync-wait、   reentrant-sync、events-v2、十个 value-<tag>；一个读线程解析帧，每个   进来的调用一个 Task，调用链放 @TaskLocal；引用、future、信号、取消、   release 计数、64 层深度、畸形帧结束会话 - 通道：fd、unix、tcp（先发 RUTIS_CHANNEL_TOKEN），按行分帧、16 MiB 上限 - 值：自己的 JSON（数字保留原文）、十种带标记的值（Rutis.DateTime /   CalendarDate / TimeOfDay / BigInt，Date、Data、Decimal、UUID、   Dictionary、Set 原生）、超界整数自动 bigint、Map 键与 Set 元素规则 - 编解码：自己的 Encoder / Decoder（不用 JSONEncoder），Any 解码为原生值 - 错误：RutisError，name / message / code / data 与错误图两个方向  一致性：RutisSessionFixture 过 runtime_conformance（Unix socket 与 loopback、畸形帧）和 value_roundtrip（数据、带标记的值、深度、release 计数）；rutis-bridge 加 feature swift。CI 加 runtimes-swift（自托管 macOS），train.mjs 加 Swift 版本文件。") | 4 days agoOct 19, 2026 |
| [AGENTS.md](https://github.com/arcships/rutis/blob/main/AGENTS.md "AGENTS.md") | [AGENTS.md](https://github.com/arcships/rutis/blob/main/AGENTS.md "AGENTS.md") | [docs(agents): skills in English](https://github.com/arcships/rutis/commit/f7a1dd6f9d7276c4f3fd69aed822bcd4f810f244 "docs(agents): skills in English  SKILL.md, the runtime contract summary and AGENTS.md rewritten in English; references re-copied from the English originals (.en.md).") | last weekOct 14, 2026 |
| [CONTRIBUTING.md](https://github.com/arcships/rutis/blob/main/CONTRIBUTING.md "CONTRIBUTING.md") | [CONTRIBUTING.md](https://github.com/arcships/rutis/blob/main/CONTRIBUTING.md "CONTRIBUTING.md") | [fix(bun): Bun 运行时没有依赖后，测试与贡献说明不再要求 bun install](https://github.com/arcships/rutis/commit/9908ca234a1253780934482df39c3a47e34d6e6d "fix(bun): Bun 运行时没有依赖后，测试与贡献说明不再要求 bun install  bun_runtime.rs 的版本过低用例原先链接 node_modules（为了 Cordis），现在不需要； docs/ci 与 CONTRIBUTING 同步。") | 4 days agoOct 18, 2026 |
| [CONTRIBUTING.zh-CN.md](https://github.com/arcships/rutis/blob/main/CONTRIBUTING.zh-CN.md "CONTRIBUTING.zh-CN.md") | [CONTRIBUTING.zh-CN.md](https://github.com/arcships/rutis/blob/main/CONTRIBUTING.zh-CN.md "CONTRIBUTING.zh-CN.md") | [fix(bun): Bun 运行时没有依赖后，测试与贡献说明不再要求 bun install](https://github.com/arcships/rutis/commit/9908ca234a1253780934482df39c3a47e34d6e6d "fix(bun): Bun 运行时没有依赖后，测试与贡献说明不再要求 bun install  bun_runtime.rs 的版本过低用例原先链接 node_modules（为了 Cordis），现在不需要； docs/ci 与 CONTRIBUTING 同步。") | 4 days agoOct 18, 2026 |
| [Cargo.lock](https://github.com/arcships/rutis/blob/main/Cargo.lock "Cargo.lock") | [Cargo.lock](https://github.com/arcships/rutis/blob/main/Cargo.lock "Cargo.lock") | [feat: Rust 服务在类型上标注 #\[rutis::service\] 即对外，不再需要 build.rs 清单（](https://github.com/arcships/rutis/commit/044d2ea02b50f2312b0db53216930f1ded69fc2d "feat: Rust 服务在类型上标注 #[rutis::service] 即对外，不再需要 build.rs 清单（#510）") [#510](https://github.com/arcships/rutis/issues/510) [）](https://github.com/arcships/rutis/commit/044d2ea02b50f2312b0db53216930f1ded69fc2d "feat: Rust 服务在类型上标注 #[rutis::service] 即对外，不再需要 build.rs 清单（#510）") | 2 days agoOct 21, 2026 |
| [Cargo.toml](https://github.com/arcships/rutis/blob/main/Cargo.toml "Cargo.toml") | [Cargo.toml](https://github.com/arcships/rutis/blob/main/Cargo.toml "Cargo.toml") | [feat: Rust 服务在类型上标注 #\[rutis::service\] 即对外，不再需要 build.rs 清单（](https://github.com/arcships/rutis/commit/044d2ea02b50f2312b0db53216930f1ded69fc2d "feat: Rust 服务在类型上标注 #[rutis::service] 即对外，不再需要 build.rs 清单（#510）") [#510](https://github.com/arcships/rutis/issues/510) [）](https://github.com/arcships/rutis/commit/044d2ea02b50f2312b0db53216930f1ded69fc2d "feat: Rust 服务在类型上标注 #[rutis::service] 即对外，不再需要 build.rs 清单（#510）") | 2 days agoOct 21, 2026 |
| [LICENSE](https://github.com/arcships/rutis/blob/main/LICENSE "LICENSE") | [LICENSE](https://github.com/arcships/rutis/blob/main/LICENSE "LICENSE") | [docs: rename min-cordis references to rutis; import research/review/s…](https://github.com/arcships/rutis/commit/2563048a2b928f8ad2a1f3bdb80fed9dc277c55e "docs: rename min-cordis references to rutis; import research/review/simplification docs") | 2 months agoAug 18, 2026 |
| [Package.swift](https://github.com/arcships/rutis/blob/main/Package.swift "Package.swift") | [Package.swift](https://github.com/arcships/rutis/blob/main/Package.swift "Package.swift") | [feat(swift): RutisApp——应用托管插件的 start / stop 与可观察状态，二进制的 dial: / liste…](https://github.com/arcships/rutis/commit/1f350081969b1909d42ddbcfd47c8f1b4731ad63 "feat(swift): RutisApp——应用托管插件的 start / stop 与可观察状态，二进制的 dial: / listen: 在它上面运行（#389）  - Remote/App.swift：RutisApp(plugins:connect:id:token:…) 拨出、RutisApp(plugins:listen:…certificate:) 监听；start() 开始拨出或绑定后返回，只抛重试修不好的；stop() 在 rutis 还能收到时逆序卸载全部行后断开；state（stopped(reason:) / connecting / connected）经 ObservationRegistrar 遵循 Observable，另有 states（AsyncStream） - 二进制的 dial: / listen: 改为一个设置取自环境变量的 RutisApp：一致性的 Swift 列同时检查应用的连接；监听的二进制收到 SIGTERM 也卸载后以 0 退出 - 报告行与清理时限按运行时（Events.Settings：log、shutdownTimeout） - RutisAppFixture 与 rutis-host tests/swift_app.rs：两个应用同名插件两个实例、stop 后使用者停下、start 后恢复、状态序列与观察；监听的应用被 peer 行连上，stop / start 后服务恢复 - 指南 docs/guide/swift-app（中英，含本地网络权限）、设计 §17.5、承诺 swift/app-start-stop、skill、README") | 3 days agoOct 20, 2026 |
| [README.md](https://github.com/arcships/rutis/blob/main/README.md "README.md") | [README.md](https://github.com/arcships/rutis/blob/main/README.md "README.md") | [docs: 0.14 不单独发布，版本写法改成 0.15](https://github.com/arcships/rutis/commit/51984596a35f201e52a02e3cbe601451c933ef39 "docs: 0.14 不单独发布，版本写法改成 0.15  迁移说明改名为 migration-0.15，Swift 依赖写法 from: \"0.15.0\"，设计稿里的里程碑与首个版本。") | 2 days agoOct 21, 2026 |
| [README.zh-CN.md](https://github.com/arcships/rutis/blob/main/README.zh-CN.md "README.zh-CN.md") | [README.zh-CN.md](https://github.com/arcships/rutis/blob/main/README.zh-CN.md "README.zh-CN.md") | [docs: 0.14 不单独发布，版本写法改成 0.15](https://github.com/arcships/rutis/commit/51984596a35f201e52a02e3cbe601451c933ef39 "docs: 0.14 不单独发布，版本写法改成 0.15  迁移说明改名为 migration-0.15，Swift 依赖写法 from: \"0.15.0\"，设计稿里的里程碑与首个版本。") | 2 days agoOct 21, 2026 |
| [SECURITY.md](https://github.com/arcships/rutis/blob/main/SECURITY.md "SECURITY.md") | [SECURITY.md](https://github.com/arcships/rutis/blob/main/SECURITY.md "SECURITY.md") | [release: 0.13.0](https://github.com/arcships/rutis/commit/15d9c0f9c17257ca3de830bc5726c6f315521fbb "release: 0.13.0  按 docs/release.md 第 1 步，从 0.12.1 升到 0.13.0（统一事件，#464）：列车 crate 与相互依赖、rutis-cli/agent/dev 的依赖、npm/Bun/Python/Go 包、 rutis-host 的运行时与平台包依赖、次版本范围 0.12 → 0.13；持久化样本 0.13.0（节点行用 0.13 的事件 export/import 写法）；发布说明定稿； docs/release.md 加 0.13.0 一节；fuzz/Cargo.lock 补上 rutis 对 serde 的依赖。") | 4 days agoOct 19, 2026 |
| [rust-toolchain.toml](https://github.com/arcships/rutis/blob/main/rust-toolchain.toml "rust-toolchain.toml") | [rust-toolchain.toml](https://github.com/arcships/rutis/blob/main/rust-toolchain.toml "rust-toolchain.toml") | [feat: add Linux dylib SDK and guarded plugin loader](https://github.com/arcships/rutis/commit/6457fcba4564e581d88fd524c9b5079c22b2dc70 "feat: add Linux dylib SDK and guarded plugin loader") | last monthSep 25, 2026 |
| View all files |

## Repository files navigation

![rutis](https://github.com/arcships/rutis/raw/main/assets/logo/brand/rutis-lockup.svg)

# rutis

[Permalink: rutis](https://github.com/arcships/rutis#rutis)

**A plugin runtime for software that iterates on itself**

Agents and long-running programs write, swap and hot-reload their own plugins, and rutis keeps every change safe.

A Rust core · plugins in TypeScript, Python, Go and Swift · across processes and machines

[![crates.io](https://camo.githubusercontent.com/4bc446ef1f66aaddafc256dc99df65ba56b17c559f9409256862a2ac938f410b/68747470733a2f2f696d672e736869656c64732e696f2f6372617465732f762f72757469732e7376673f6c6162656c3d6372617465732e696f)](https://crates.io/crates/rutis)[![npm](https://camo.githubusercontent.com/b7680d6f131a42ba3a580fbf68035e02c498ce12af94f7385b74cf4a4a338130/68747470733a2f2f696d672e736869656c64732e696f2f6e706d2f762f4061726373686970732f72757469732e7376673f6c6162656c3d6e706d)](https://www.npmjs.com/package/@arcships/rutis)[![PyPI](https://camo.githubusercontent.com/b726a3533e8919687c1b5ed6c4ce8e21b756d8bb66fa5549ae0c5a8b62821af1/68747470733a2f2f696d672e736869656c64732e696f2f707970692f762f72757469733f6c6162656c3d50795049)](https://pypi.org/project/rutis/)[![docs.rs](https://camo.githubusercontent.com/b12d1fd0f7e986c1b74c60acac177724bfc9fdab1e0b2af34e573a2f7431e0be/68747470733a2f2f696d672e736869656c64732e696f2f646f637372732f72757469733f6c6162656c3d646f63732e7273)](https://docs.rs/rutis)[![CI](https://github.com/arcships/rutis/actions/workflows/ci.yml/badge.svg)](https://github.com/arcships/rutis/actions/workflows/ci.yml)[![License: MIT](https://camo.githubusercontent.com/7013272bd27ece47364536a221edb554cd69683b68a46fc0ee96881174c4214c/68747470733a2f2f696d672e736869656c64732e696f2f62616467652f6c6963656e73652d4d49542d626c75652e737667)](https://github.com/arcships/rutis/blob/main/LICENSE)

[Quick start](https://github.com/arcships/rutis#quick-start) · [Guides](https://github.com/arcships/rutis/blob/main/docs/guide/README.en.md) · [Design philosophy](https://github.com/arcships/rutis/blob/main/docs/design-philosophy.en.md) · [API docs](https://docs.rs/rutis) · [中文](https://github.com/arcships/rutis/blob/main/README.zh-CN.md)

When software is itself an agent, or is built by agents, it cannot wait for someone else to wrap the world for it. To reach a new API, model, tool or device, it writes a plugin, tries it, changes it and replaces it, while it keeps running. The connection then becomes part of the program: with a lifecycle, visible, and cleaned up when it goes.

Doing that over and over is only safe on a runtime that guarantees a few things: nothing starts before what it depends on is there; everything a plugin registered is released exactly once when it stops; a failed load rolls back; and when an implementation is replaced, only what uses it restarts. rutis is that runtime. Plugins declare the services they need and provide, and rutis decides when they start, stop and start again.

The lifecycle model comes from [Cordis](https://github.com/shigma/cordis). rutis implements it once, in a small Rust core, and carries it to other languages, other processes and other machines.

## The loop

[Permalink: The loop](https://github.com/arcships/rutis#the-loop)

|  | What rutis gives you |
| --- | --- |
| **Make** a connection | `rutis-host new --lang node|bun|python|go` creates a plugin project. Plugins run in the host's process, in a language runtime, or on another machine, and call each other's services by name. |
| **Understand** it | `rutis-host check` lists every plugin's dependencies and what it provides, and fails on a service nothing provides. In Rust, `ctx.diagnostics()` shows each plugin's state, dependencies and bindings. |
| **Iterate** on it | `rutis-host dev` reloads a plugin when its files change. Configuration updates live. Replace a provider, even with one in another language, and the plugins using it follow. |
| **Without breaking** | Gated start, LIFO cleanup that runs exactly once, rollback on failure. Synchronous calls that would deadlock across runtimes are refused. Loading, unloading and replacing again and again leaves nothing behind. |

## Quick start

[Permalink: Quick start](https://github.com/arcships/rutis#quick-start)

### Without Rust

[Permalink: Without Rust](https://github.com/arcships/rutis#without-rust)

```
npx @arcships/rutis-host new weather --lang node
cd weather && npm install
npx rutis-host dev          # run the plugin, reload it when files change
npx rutis-host check        # what each plugin needs and provides
```

The same works for other languages: `bunx --bun @arcships/rutis-host new weather --lang bun`, `uvx rutis-host new weather --lang python` (then `uv sync`, `uv run rutis-host dev`), or `rutis-host new weather --lang go` (then `go mod tidy`, `rutis-host dev`).

```
import { definePlugin } from '@arcships/rutis'

interface Llm {
  ask(question: string): Promise<string>
}

export default definePlugin<{ city?: string }>({
  inject: ['llm'],                             // services it needs: starts once all are there
  apply(ctx, config) {
    const llm = ctx.use<Llm>('llm')
    const city = config.city ?? 'Oslo'
    ctx.provide('weather', {                   // the service it offers, by name, to every language
      today: () => llm.ask(`weather in ${city}`),
    })
  },
})
```

`llm` can come from another plugin in the same process, from a Python plugin, or from another machine; this plugin stays the same. The full workflow is in the guides for [TypeScript](https://github.com/arcships/rutis/blob/main/docs/guide/typescript-plugin.en.md), [Bun](https://github.com/arcships/rutis/blob/main/docs/guide/bun-plugin.en.md), [Python](https://github.com/arcships/rutis/blob/main/docs/guide/python-plugin.en.md), [Go](https://github.com/arcships/rutis/blob/main/docs/guide/go-plugin.en.md) and [Swift](https://github.com/arcships/rutis/blob/main/docs/guide/swift-plugin.en.md).

### In Rust

[Permalink: In Rust](https://github.com/arcships/rutis#in-rust)

```
cargo add rutis
cargo add tokio --features full
```

```
use std::sync::Arc;
use rutis::{BoxFuture, CordisError, Ctx, Effect, Plugin, Typed, TypedPlugin};

/// A service is a type.
struct Greeting(String);

/// Provides Greeting. What apply registers is released when the plugin stops.
struct Greeter(&'static str);

impl Plugin for Greeter {
    fn name(&self) -> &str { "greeter" }

    fn apply<'a>(&'a self, ctx: &'a Ctx) -> BoxFuture<'a, Result<Effect, CordisError>> {
        Box::pin(async move {
            ctx.provide(Greeting(format!("hello from {}", self.0)))?;
            Ok(Effect::Done)
        })
    }
}

/// Depends on Greeting: starts when it appears, restarts when it is replaced.
struct Listener;

impl TypedPlugin for Listener {
    type Deps = (Arc<Greeting>,);

    fn name(&self) -> &str { "listener" }

    fn apply<'a>(&'a self, _: &'a Ctx, (greeting,): Self::Deps) -> BoxFuture<'a, Result<Effect, CordisError>> {
        Box::pin(async move {
            println!("{}", greeting.0);
            Ok(Effect::Done)
        })
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let ctx = Ctx::root()?;
    let listener = ctx.plugin(Typed::new(Listener));  // waits for a Greeting

    let english = ctx.plugin(Greeter("English"));
    (&english).await?;
    (&listener).await?;                               // hello from English

    english.dispose().await?;                         // the listener stops…
    let esperanto = ctx.plugin(Greeter("Esperanto"));
    (&esperanto).await?;
    (&listener).await?;                               // …and starts again: hello from Esperanto

    ctx.shutdown().await?;
    Ok(())
}
```

Nothing touched `Listener`: when the provider changed, it stopped and started again on its own. Run it from the repository with `cargo run -p rutis --example quickstart`. To run TypeScript, Python and Go plugins inside your Rust application, see [embedding in Rust](https://github.com/arcships/rutis/blob/main/docs/guide/rust-host.en.md).

## From experiment to production

[Permalink: From experiment to production](https://github.com/arcships/rutis#from-experiment-to-production)

A plugin depends on a service's **name**, never on its implementation, its language or where it runs. So a capability can start as a quick experiment and harden over time, while everything that uses it stays the same:

1. **Try**: write it in Python or TypeScript, perhaps with an agent, and let `rutis-host dev` reload it on every change.
2. **Prove**: run it in a real host, using and used by other plugins; the service's name and methods settle here.
3. **Solidify**: move it to another machine, or rewrite the parts that have stood the test of time in Rust.

Render

Loading

```
flowchart LR
    subgraph s1["Try"]
        p1["planner"] -->|calendar| c1["Python plugin"]
    end
    subgraph s2["Move to the internal network"]
        p2["planner"] -->|calendar| c2["Plugin on an internal node"]
    end
    subgraph s3["Solidify"]
        p3["planner"] -->|calendar| c3["Rust implementation"]
    end
    s1 ~~~ s2 ~~~ s3
```

Across all three stages, not one line of `planner` changes and the host does not restart.

## How it works

[Permalink: How it works](https://github.com/arcships/rutis#how-it-works)

rutis is a small application operating system. The core is the kernel; everything it connects to is a plugin under the same lifecycle:

| Operating system | rutis |
| --- | --- |
| Kernel: small, stable, rarely changed | The `rutis` core, depending only on tokio, tokio-util, thiserror, serde and serde\_json |
| Processes | Plugins; language runtimes, remote nodes and dylibs are plugins too |
| System calls | Services, provided and used by name or by type |
| Drivers | Language runtimes, node links, Cordis mounts |
| Scheduling and reclamation | Start once dependencies are ready, stop when they go away, clean up in reverse order |

Render

Loading

```
flowchart LR
    subgraph host["Host (Rust)"]
        core["rutis core<br/>lifecycle · dependencies · cleanup"]
        rust["Rust / dylib plugins"]
    end
    js["Node / Bun runtime<br/>npm ecosystem, Cordis plugins"]
    py["Python runtime<br/>ML and data ecosystem"]
    go["Go plugin binaries"]
    peer["Nodes on other machines<br/>their processes and devices"]
    core --- rust
    core <--> js
    core <--> py
    core <--> go
    core <-->|WebSocket + TLS| peer
```

The lifecycle model lives only in the core, and every guarantee is pinned by tests; the other languages get a small SDK instead of a copy of the framework. Each plugin runs in a fiber whose state follows its dependencies:

Render

Loading

```
stateDiagram-v2
    direction LR
    [*] --> Pending
    Pending --> Loading : dependencies ready
    Loading --> Active : apply succeeds
    Loading --> Failed : apply fails, rolled back
    Active --> Unloading : dependency gone / config update / dispose
    Failed --> Unloading : dependency back / config update / restart
    Unloading --> Pending : cleanup done
    Unloading --> Disposed : terminated
    Disposed --> [*]
```

Services are registered by type in Rust and by name across languages. Events are one logical bus across languages, processes and machines, dispatched in five ways (emit, parallel, serial, waterfall and synchronous bail) that mean the same wherever the listeners are. `rutis-loader` describes the plugins to run as layered configuration and keeps reconciling the running system toward it. Hosts link over WebSocket and TLS to share services, run plugins on another machine, share events and reconnect after a drop.

## Trade-offs

[Permalink: Trade-offs](https://github.com/arcships/rutis#trade-offs)

- **Processes and latency**: each language needs at least one process, and a synchronous cross-language call takes about 30 µs (measured on the Node side). Hot paths belong in Rust or in one runtime.
- **Waiting across a boundary has limits**: events and services keep their semantics across processes and machines ( [unified events](https://github.com/arcships/rutis/blob/main/docs/design-events-2026-10-18.en.md)), but a synchronous wait cannot form a cycle or outlive the far end: a synchronous call or `bail` that would is refused with an error. What cannot cross a boundary is a [written rule](https://github.com/arcships/rutis/blob/main/docs/requirements-protocol-plugins.en.md), not a silent degradation.
- **Shared failure**: plugins in one runtime share its process. Isolation means more runtime instances.

The [design philosophy](https://github.com/arcships/rutis/blob/main/docs/design-philosophy.en.md) explains these choices, and how rutis differs from Cordis.

## Packages

[Permalink: Packages](https://github.com/arcships/rutis#packages)

| For | Rust (crates.io) | JavaScript (npm) | Python (PyPI) |
| --- | --- | --- | --- |
| The core | [`rutis`](https://crates.io/crates/rutis) |  |  |
| Writing plugins | [`rutis-sdk`](https://crates.io/crates/rutis-sdk) (dylib plugins) | [`@arcships/rutis`](https://www.npmjs.com/package/@arcships/rutis) | [`rutis`](https://pypi.org/project/rutis/) |
| Running plugins in your app | [`rutis-loader`](https://crates.io/crates/rutis-loader), [`rutis-bridge`](https://crates.io/crates/rutis-bridge), [`rutis-dylib`](https://crates.io/crates/rutis-dylib) (dylib plugins) | [`@arcships/rutis-runtime`](https://www.npmjs.com/package/@arcships/rutis-runtime) (Node), [`@arcships/rutis-bun`](https://www.npmjs.com/package/@arcships/rutis-bun) (Bun) | [`rutis`](https://pypi.org/project/rutis/) |
| A host without Rust | [`rutis-host`](https://crates.io/crates/rutis-host) | [`@arcships/rutis-host`](https://www.npmjs.com/package/@arcships/rutis-host) | [`rutis-host`](https://pypi.org/project/rutis-host/) |

Go plugins use the module [`github.com/arcships/rutis/go/rutis`](https://github.com/arcships/rutis/blob/main/go/rutis): the SDK, and the runtime each plugin binary carries. Swift plugins (macOS) use the Swift package of this repository, [`Rutis`](https://github.com/arcships/rutis/blob/main/swift/README.md) (`.package(url: "https://github.com/arcships/rutis", from: "0.15.0")`), the same way.

All of these form a release train: released together at one version, currently 0.13. Use the same version for every rutis package.

## Built with rutis

[Permalink: Built with rutis](https://github.com/arcships/rutis#built-with-rutis)

| Project |  |
| --- | --- |
| [rutis-agent](https://github.com/arcships/rutis/blob/main/crates/rutis-agent) · [rutis-cli](https://github.com/arcships/rutis/blob/main/crates/rutis-cli) | A minimal coding agent in which the model service, tools, streaming driver and TUI are all plugins. Try it offline with `cargo run -p rutis-cli -- --scripted`. |
| [rutis-host](https://github.com/arcships/rutis/blob/main/crates/rutis-host) | A host without Rust: runs TypeScript, JavaScript, Python, Go and Swift plugins from a `rutis.json`, reloads them during development, links machines. |
| [rutis-dsh](https://github.com/arcships/rutis/blob/main/crates/rutis-dsh) | Runs the full dsh web interface inside a rutis host, with model calls served by aimux in the same process. |
| [aimux-llm](https://github.com/arcships/rutis/blob/main/crates/aimux-llm) | Wraps [aimux](https://crates.io/crates/aimux-core) as an LLM service plugin. |

## Documentation

[Permalink: Documentation](https://github.com/arcships/rutis#documentation)

- **[Guides](https://github.com/arcships/rutis/blob/main/docs/guide/README.en.md)**: organized by task. Plugins in TypeScript, Bun, Python, Go and Swift, running rutis-host, linking nodes, embedding in Rust, working with Cordis.
- **[Design philosophy](https://github.com/arcships/rutis/blob/main/docs/design-philosophy.en.md)**: why rutis exists, the shape that follows, its costs and principles.
- **[Application design guide](https://github.com/arcships/rutis/blob/main/docs/development-guide.en.md)**: splitting an app into plugins, drawing the dependency graph, designing reloads and multiple instances.
- **[Development handbook](https://github.com/arcships/rutis/blob/main/docs/development-handbook.en.md)**: API usage, resource cleanup, events, troubleshooting and verification.
- **[Core features](https://github.com/arcships/rutis/blob/main/docs/core-features.en.md)**: config hot update, dynamic events, interception, diagnostics, and the boundaries of each.
- **[Guarantee registry](https://github.com/arcships/rutis/blob/main/docs/guarantees.en.md)**: what rutis promises, at what level, and which tests verify each promise.
- **[API docs](https://docs.rs/rutis)**: the complete reference on docs.rs.
- **Design records**: the [core design](https://github.com/arcships/rutis/blob/main/docs/design-rust-port.en.md), the [spec-by-spec parity check against Cordis](https://github.com/arcships/rutis/blob/main/docs/cordis-spec-parity-2026-08-18.en.md), and every design record in [docs](https://github.com/arcships/rutis/blob/main/docs).
- **Upgrading**: [0.8 → 0.9](https://github.com/arcships/rutis/blob/main/docs/migration-0.8-to-0.9.en.md) · [0.7 → 0.8](https://github.com/arcships/rutis/blob/main/docs/migration-0.7-to-0.8.en.md) · [from rutis-interop to 0.7](https://github.com/arcships/rutis/blob/main/docs/migration-interop-to-0.7.en.md) · [0.6.0 → 0.6.1](https://github.com/arcships/rutis/blob/main/docs/migration-0.6.0-to-0.6.1.en.md) · [0.5 → 0.6](https://github.com/arcships/rutis/blob/main/docs/migration-0.5-to-0.6.en.md) · [0.3 → 0.5](https://github.com/arcships/rutis/blob/main/docs/migration-0.3-to-0.5.en.md) · [0.1 → 0.2](https://github.com/arcships/rutis/blob/main/docs/migration-0.1-to-0.2.en.md)

## Platforms and status

[Permalink: Platforms and status](https://github.com/arcships/rutis#platforms-and-status)

rutis is at 0.x and its API is still evolving. Breaking changes are listed in the release notes and come with a migration guide.

- **The core** is pure Rust with tokio, tokio-util, thiserror, serde and serde\_json as its only dependencies; it needs Rust 1.88 or later.
- **Language runtimes and rutis-host** (Node, Bun, Python and Go rows, remote runtimes, shared services, peers, Cordis mounts) run on Linux, macOS and Windows x64 (MSVC); they need Node 22+, Bun 1.4+ or Python 3.10+; Go plugins are compiled binaries, built with Go 1.24+. Swift plugins are compiled binaries for macOS 14+, built with a Swift 6 toolchain. The Bun runtime is not tested on Windows yet.
- **dylib plugins** load on Linux, macOS and Windows x64 (MSVC).

## Contributing

[Permalink: Contributing](https://github.com/arcships/rutis#contributing)

Issues and pull requests are welcome: bugs, places where the docs are unclear, features you would like. Please read the [contributing guide](https://github.com/arcships/rutis/blob/main/CONTRIBUTING.md) first, and report security issues privately as described in the [security policy](https://github.com/arcships/rutis/blob/main/SECURITY.md).

## Acknowledgements and license

[Permalink: Acknowledgements and license](https://github.com/arcships/rutis#acknowledgements-and-license)

The design of rutis comes from [Cordis](https://github.com/shigma/cordis) by [Shigma](https://github.com/shigma). Without Cordis's thinking about plugins, contexts and dependencies, this project would not exist.

Released under the [MIT](https://github.com/arcships/rutis/blob/main/LICENSE) license.

## About

A plugin runtime for software that iterates on itself — the substrate where agents write, swap and hot-reload their own plugins in Rust, TypeScript, Python and Go, across processes and machines.

### Topics

[agent-framework](https://github.com/topics/agent-framework) [ai-agents](https://github.com/topics/ai-agents) [bun](https://github.com/topics/bun) [cordis](https://github.com/topics/cordis) [dependency-injection](https://github.com/topics/dependency-injection) [go](https://github.com/topics/go) [hot-reload](https://github.com/topics/hot-reload) [lifecycle](https://github.com/topics/lifecycle) [plugin-runtime](https://github.com/topics/plugin-runtime) [plugin-system](https://github.com/topics/plugin-system) [polyglot](https://github.com/topics/polyglot) [python](https://github.com/topics/python) [recursive-self-improvement](https://github.com/topics/recursive-self-improvement) [rust](https://github.com/topics/rust) [self-evolving](https://github.com/topics/self-evolving) [tokio](https://github.com/topics/tokio) [typescript](https://github.com/topics/typescript)

### Resources

[Readme](https://github.com/arcships/rutis#readme-ov-file)

[MIT license](https://github.com/arcships/rutis#MIT-1-ov-file)

### Contributing

[Contributing](https://github.com/arcships/rutis#contributing-ov-file)

### Security policy

[Security policy](https://github.com/arcships/rutis#security-ov-file)

[Activity](https://github.com/arcships/rutis/activity)

[Custom properties](https://github.com/arcships/rutis/custom-properties)

### Stars

**153** stars

### Watchers

**0** watching

### Forks

[**11** forks](https://github.com/arcships/rutis/forks)

[Report repository](https://github.com/contact/report-content?content_url=https%3A%2F%2Fgithub.com%2Farcships%2Frutis&report=arcships+%28user%29)

## [Releases](https://github.com/arcships/rutis/releases) 15 (15)

[rutis v0.13.0Latest\\
\\
4 days agoOct 19, 2026](https://github.com/arcships/rutis/releases/tag/v0.13.0)

[\+ 14 releases](https://github.com/arcships/rutis/releases)

## [Contributors](https://github.com/arcships/rutis/graphs/contributors) 4 (4)

- [![@eric8810](https://avatars.githubusercontent.com/u/756579?s=64&v=4)](https://github.com/eric8810) [**eric8810** scotares](https://github.com/eric8810)
- [![@claude](https://avatars.githubusercontent.com/u/81847?s=64&v=4)](https://github.com/claude) [**claude** Claude](https://github.com/claude)
- [![@yuanhao](https://avatars.githubusercontent.com/u/313650?s=64&v=4)](https://github.com/yuanhao) [**yuanhao** Yuanhao Li](https://github.com/yuanhao)
- [![@wanjinhao1](https://avatars.githubusercontent.com/u/34562501?s=64&v=4)](https://github.com/wanjinhao1) [**wanjinhao1** Kratos](https://github.com/wanjinhao1)

## Languages

- [Rust65.8%](https://github.com/arcships/rutis/search?l=rust)
- [JavaScript7.1%](https://github.com/arcships/rutis/search?l=javascript)
- [Swift6.2%](https://github.com/arcships/rutis/search?l=swift)
- [Python5.6%](https://github.com/arcships/rutis/search?l=python)
- [Go5.5%](https://github.com/arcships/rutis/search?l=go)
- [Kotlin5.4%](https://github.com/arcships/rutis/search?l=kotlin)
- [Other4.4%](https://github.com/arcships/rutis/search?l=Other)

You can’t perform that action at this time.