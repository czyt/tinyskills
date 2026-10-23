---
name: use-rutis
description: Use when 编写 rutis 插件（TypeScript/Bun/Python/Go/Swift/Kotlin）、在 Rust 中嵌入 rutis host、写 rutis.json 运行配置、排查插件不加载/插件不启动/服务未提供/服务冲突/事件收不到/跨进程调用失败/死锁、热重载不生效、生命周期异常、跨机器节点连接、需要服务按依赖启停或被替换时热切换。触发词：rutis、rutis-host、definePlugin、ctx.provide、inject、Cordis、plugin runtime、hot reload、SyncWaitCycle。
---

# rutis 插件开发

rutis 是"会自我迭代的软件"的插件运行时：Rust 核心 + 多语言插件（TypeScript、Bun、Python、Go、Swift、Kotlin），支持跨进程、跨机器的服务共享与事件总线。生命周期模型来自 Cordis。

**核心原则：插件依赖的是服务的名字，不是它的实现、语言或位置。** 一个能力可以先在 Python 里试验，再无缝固化成 Rust——使用它的代码一行不改。

## 按任务路由

| 任务 | 读哪份 reference |
|---|---|
| 写 TypeScript / Node 插件 | [typescript-plugin.md](references/typescript-plugin.md) |
| 写 Bun 插件（TS 免构建） | [bun-plugin.md](references/bun-plugin.md) |
| 写 Python 插件（uv） | [python-plugin.md](references/python-plugin.md) |
| 写 Go 插件（编译为二进制） | [go-plugin.md](references/go-plugin.md) |
| 写 Swift 插件（macOS 系统能力） | [swift-plugin.md](references/swift-plugin.md) |
| 声明、ctx、事件五模式、跨进程传值规则 | [plugin-api.md](references/plugin-api.md) |
| 写 rutis.json、部署、运行时管理 | [rutis-host.md](references/rutis-host.md) |
| 项目背景与 Rust 内嵌（含 Rust/Kotlin 插件写法） | [rutis-readme.md](references/rutis-readme.md) |
| 某个具体报错/症状（不启动、收不到事件、调用失败…） | 先查本文件「失败模式速查」；未命中再按主题查上表 |

## 开发工作流

1. **脚手架**：`rutis-host new <name> --lang node|bun|python|go|swift`（无 Rust 时：`npx @arcships/rutis-host new weather --lang node`）。生成的项目含插件源文件、免 host 单测、`rutis.dev.json`、发布 workflow。
2. **写插件**：声明 `inject`（需要的服务）→ `apply(ctx, config)` 里 `ctx.use(name)` 取依赖、`ctx.provide(name, value)` 提供服务、`ctx.effect(cleanup)` 注册清理。配置用 JSON Schema（Go/Swift/Kotlin 从类型自动推导）。
3. **单测**（不需要 host）：TS 用 `load()` from `@arcships/rutis/testing`；Python `rutis.testing.load`；Go `rutistest.Load`；Swift `RutisTest.load`；Bun `bun test`。strict 模式默认开启，单进程假设的代码在这里会失败——这是设计意图。
4. **本地运行**：`rutis-host dev`（按文件变化热重载；Go/Swift 改动自动重建）。`rutis-host check`（不运行插件，列出每行的依赖/服务/配置 schema，CI 里用 `--strict`）。
   🔴 **CHECKPOINT（发布门槛）：** 单测（strict 模式）与 `check --strict` 全部通过后才可发布；strict 失败是跨进程不兼容的信号，不是噪声。发布有副作用（push `v*` tag 即触发 npm/PyPI/Release），发布前向用户确认版本号与目标 registry。
5. **发布**：TS/Python 推 `v*` tag 自动发 npm/PyPI；Go/Swift 出各平台二进制到 GitHub Release。

## 多语言对照速查

| 概念 | TypeScript (`definePlugin`) | Python (`define_plugin`) | Go (`rutis.Define`) | Swift (`Rutis.define`) |
|---|---|---|---|---|
| 需要的服务 | `inject: ['llm']` | `inject=["llm"]` | `Inject: []string{"llm"}` | `inject: ["llm"]` |
| 提供服务 | `ctx.provide('weather', obj)` | `ctx.provide("weather", obj)` | `ctx.Provide("weather", &w)` | `ctx.provide("weather", w)` |
| 使用服务 | `ctx.use<Llm>('llm')` | `ctx.use("llm")` | `ctx.Use("llm", &llm)` | `try ctx.use("llm", LLMProxy.self)` |
| 清理 | `apply` 返回函数 或 `ctx.effect(fn)` | `return lambda: None` 或 `ctx.effect` | `ctx.Effect(func(ctx) error)` | `ctx.effect { }` |
| 配置 | JSON Schema | JSON Schema（或模块变量 `Config`） | 类型 `C` 自动推导 | `@RutisConfig` Decodable 类型 |
| 监听事件 | `ctx.on(name, fn)` | `ctx.on(name, fn)` | `ctx.On(name, fn)` | `ctx.on(name) { }` |
| 五种发送 | `ctx.emit / parallel / serial / waterfall / bail` | 同左；`parallel`/`serial`/`waterfall` 需 await（`bail` 同步） | `ctx.Emit / Parallel / Serial / Waterfall / Bail` | `try ctx.emit / try await parallel / …` |

**Rust**（核心 API）：`impl Plugin for T { fn apply(&self, ctx: &Ctx) }`，`ctx.provide(Greeting(...))`（按类型注册），`TypedPlugin` + `type Deps = (Arc<Greeting>,)` 按类型注入；宿主内 `#[rutis::service]` 标注的类型自动跨语言可见。**Kotlin**：`Rutis.define<C> { ctx, config -> }` + `@RutisService`/`@RutisClient` 注解（KSP 生成方法表）。完整代码见 [rutis-readme.md](references/rutis-readme.md) 的 In Rust 段。

## 生命周期（必须理解的行为）

- **门控启动**：`inject` 的服务全部就绪才 `apply`；任一被撤销就停止清理，服务回来时自动重启。
- **LIFO 清理恰好一次**：`apply` 返回的清理函数先跑，`ctx.effect` 注册的按逆序跑；宿主停止时每个清理有 deadline（默认 10s，`--shutdown-timeout` 调整），超时不再等待并退出码 2。
- **替换即重启**：配置变更 → 清理后用新配置重新 `apply`；提供者被替换 → 使用者自动重启（不需要改使用者的代码）。
- **服务名唯一**：同名服务已有提供者时，后提供的插件加载失败，错误会指出双方名字。
- **宿主消失**：运行时发现连接关闭，自行卸载全部插件后退出；插件遗留的 timer/socket 不会让它保持运行。

## 事件总线（跨语言/进程/机器一条逻辑总线）

一条规则：**无论事件在哪发出、监听者在哪，结果等同所有监听者在同一进程**。注册自动上报、无需声明。

| 模式 | 发送者得到 | 监听者失败时 |
|---|---|---|
| `emit` | 立即返回不等待 | 谁也不通知，在监听者所在处记一行日志 |
| `parallel` | 等全部完成 | 全部跑完，抛 `AggregateError`（按注册顺序） |
| `serial` | 第一个结果（`undefined`/`None`/`nil`/`false` 算"无结果"） | 抛出，后续不跑 |
| `waterfall` | 链式改写：监听者最后一个参数是 `next()` | 抛给发送者；`next` 调两次报 `WaterfallNext` |
| `bail` | 同 `serial` 但同步 | 同步等待受死锁检测约束 |

同步边界：跨进程同步调用约 30µs；**会形成等待环的同步调用/`bail` 直接报 `SyncWaitCycle` 拒绝**，不会静默死锁。热路径放 Rust 或单一运行时内。

## 跨进程传值要点

- 数据（数字/字符串/数组/普通对象）**复制**；函数、Promise、带方法的对象**按引用**（对端拿到代理）。
- `Error` 作为值传递 `{name, message}`（TS 另有 `stack`），可带 `code` 和 `data`。
- 十种特殊值各语言原生类型对应（时间/日期/二进制/大整数/Decimal/UUID…），JS 收到无对应类型的是字符串；构造用 `@arcships/rutis` 的 `rutis.datetime()` 等构造器。
- 嵌套最深 64 层，超出发送方直接拒绝该次调用；循环引用、`NaN`/`Infinity`、JS Symbol、Go channel 不能跨进程。

## 失败模式速查（症状 → 修复）

| 症状 | 原因与修复 |
|------|-----------|
| 插件一直 `waiting for its services` | `inject` 的服务没人提供：`rutis-host check` 指出缺哪个；运行时才提供的服务用 `check --strict` 变错误来排查 |
| 加载失败 `service X is already provided by row Y` | 服务名冲突：一个名字只有一个提供者；换名或去掉后加载的那份 |
| 同步调用报 `SyncWaitCycle` | 同步等待会成环；改 async 方法、换时机，或当失败处理——不要立即重试 |
| `bail` 报 `AsyncListener` | `bail`/`waterfall_sync` 不能调 async 监听者（JS async 函数、Python `async def`、Rust `on`）；改用 `serial` |
| 单测过但跨进程失败 | 单进程共享内存假设：改了传入的对象、传了不可跨进程的值（Symbol/循环引用/Go channel）；strict 模式测试就是为此暴露 |
| Python 死锁 | 同步等待期间会重入处理其他调用：**调用别的服务时不要持有锁** |
| Go 并发崩溃 | 每个调用在独立 goroutine：提供的对象必须并发安全；**把收到的 ctx 传下去**（调用链在里面），不要用 `context.Background()` |
| 水瀑布收不到下游结果 | waterfall 监听者没调 `next()`（等于否决）；Go 里 `next` 是最后一个参数 `rutis.Next`，Swift 是最后参数 `Rutis.Next<R>` |
| 配置改了没生效 | `rutis.json` 运行中变更：Unix 发 `SIGUSR1` 或加 `--watch-config`；`runtimes.go/swift` 和 `remote` 的变更需重启宿主 |
| Go/Swift 二进制没被加载 | 放进 `runtimes.go.dir`/`runtimes.swift.dir` 目录（目录整体可信，应专用）；`check` 会列出每个二进制及其 SDK/插件 API 版本，旧 SDK 编译的不能跑 |
| 清理没跑完，退出码 2 | 清理超过 deadline（默认 10s）或期间收到第二个信号；清理不要无限等待，必须完成的工作不能只依赖 cleanup |

## 反例黑名单（不要做）

| # | 不要做 | 原因/替代 |
|---|--------|----------|
| 1 | 在同步方法里等待需要事件循环推进的结果（如等 Promise） | 产生 `SyncWaitCycle`；改成 async 方法 |
| 2 | 调用其他服务时持有锁（Python/Go） | 同步等待会重入；Go 每调用一 goroutine |
| 3 | Go 里用 `context.Background()` 调其他服务 | 调用链丢失，同步回调对端认不出来；传收到的 ctx |
| 4 | 依赖"同进程对象可以直接改"的共享内存行为 | 跨进程是复制；strict 单测会暴露 |
| 5 | 立即重试被拒的 `SyncWaitCycle` 调用 | 大概率再次成环；改 async 或换时机 |
| 6 | 清理函数里无限等待 | deadline 后不再等待；必须完成的工作不能只靠 cleanup |
| 7 | 混用不同版本的 rutis 包 | 全部包是统一版本列车（当前 0.13）；用同一版本 |
| 8 | 凭据写进 `rutis.json` | 凭据只从环境变量读（`RUTIS_TOKEN` 等）；进程运行中无法撤销 token，需换 token 重启 |
| 9 | 把热路径放在跨语言同步调用上 | 每次约 30µs 进程边界开销；热路径进 Rust 或单运行时 |
| 10 | 在 `rutis.json` 里发明字段 | 未知字段是错误（rows 里是警告）；拼写错误从不被静默忽略 |

## 参考与出处

- 仓库：[arcships/rutis](https://github.com/arcships/rutis)（MIT）；设计源自 [Cordis](https://github.com/shigma/cordis)
- 本 skill 的 references 是官方 guide 全文快照（2026-10，v0.13/Plugin API 3）：[plugin-api.md](references/plugin-api.md) 是声明/ctx/事件/传值的权威表；各语言 guide 含从建项目到发布的完整实例
- rutis 处于 0.x，破坏性变更见 release notes 与迁移指南（0.12→0.13 事件协议不与旧版混用）；版本要求：Rust 1.88+、Node 22+、Bun 1.4+、Python 3.10+、Go 1.24+、Swift 6/macOS 14+
