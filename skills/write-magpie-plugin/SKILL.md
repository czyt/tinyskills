---
name: write-magpie-plugin
description: Use when 为 magpie（usemagpie.ai）编写供应商插件、把某个 AI 套餐/订阅接入 magpie、写 OpenCode provider plugin、排查插件加载失败或登录不工作、实现 auth/usage/refresh/checkin 钩子、token 过期续期、多账号管理、发布插件到 npm 或 magpie-community、写网关中间件（middleware/strategies/onProvider）、异步网关请求钩子（hooks/onRequest/onResponse）、工具插件、Agent 插件、窗口页面与面板（page/panels/actions）、每日签到 checkin、额度 quota 显示、serviceTiers、maxConcurrency、插件更新与同 id 冲突。English: write a provider plugin for usemagpie, gateway middleware, magpie plugin not loading.
---

# Magpie 插件开发

为 magpie（usemagpie.ai）编写供应商插件：登录某个 AI 服务、替它发请求，使它成为 magpie 的供应商。magpie 运行 OpenCode v1 供应商插件，为 OpenCode 写的插件不用改就能用；magpie 专属钩子（`auth.usage`、`auth.refresh`、`auth.checkin`、`magpie.*` 字段）OpenCode 会忽略，一个包可以同时服务两边。除供应商插件外还有异步网关请求钩子、中间件、工具、Agent、页面/面板等形态（见「其他插件形态」）。

**核心原则：插件 = 一个 async 函数返回一组钩子；先分清"OpenCode 标准"与"magpie 专属"，再动手。**

完整 API 细节查 [references/plugin-doc-full.md](references/plugin-doc-full.md)（官方文档全文）；现成参考实现见 [magpie-community/plugins](https://github.com/magpie-community/plugins)（cline、cursor、zed、grok、zcode 等 20+ 个，含审核标准）。

## 开发工作流

1. **确认接入形态**（三问，答完与用户确认再动手）：
   - 登录方式？API key（`type: "api"`）/ 浏览器或设备码（`type: "oauth"` + `authorize` 返回 url+callback）。
   - 模型走什么 API？见下方「API 对照表」，决定 `npm` 字段。
   - 模型列表是静态还是账号相关？静态写 `config` 钩子；账号相关加 `provider.models` 钩子。
2. **建包**：`package.json`（`"type": "module"`，入口 `index.mjs` 或 `index.ts`，keywords 含 `opencode`+`opencode-plugin`+`<厂商>`）+ 入口文件导出一个 async 函数。
3. **实现钩子**（最小集）：`config`（声明供应商，默认值在前+用户配置 spread 在后，补齐但不覆盖）→ `auth`（methods + loader）→ 按需 `provider.models`、`auth.usage`、`auth.refresh`。
4. **沙箱测试**（绝不在日常 magpie 上测）：

   ```bash
   sb=$(mktemp -d)
   m() { env HOME=$sb XDG_CONFIG_HOME=$sb/.config XDG_CACHE_HOME=$sb/.cache MAGPIE_ADDR=127.0.0.1:3499 magpie "$@"; }
   m plugin add ./<插件目录>   # 文件夹就地加载
   m plugin --json             # 方式、账号、模型、加载错误
   m plugin login <id>         # 每种方式、每个提问
   m provider test <id>        # 每种 API 发一个小请求
   m provider test <id> <model> # 或只测指定的模型
   m quota                     # usage 钩子
   m plugin logout <id>        # 登出后重测登录流程
   ```

   🔴 **CHECKPOINT（测试通过标准）：** `m plugin --json` 无加载错误、`m provider test` 各模型全过、`m quota`（若实现了 usage）显示正确——全部通过才进入发布。测试失败先查「失败模式速查」，修复后重测；不得跳过测试直接发布。
5. **发布**：npm 照常发布（搜索靠 keywords：`opencode` + `auth`/`plugin`/`provider` 之一）；想进推荐列表给 [magpie-community/plugins](https://github.com/magpie-community/plugins) 的 `registry.json` 提 PR（需 `name`、`providers`、`icon`、双语 `summary`；中间件/工具/页面/Agent 条目写 `kind` 且不写 providers；`MAGPIE_PLUGIN_MARKET=<url>` 可先测自己的条目，`off` 只用内置副本）；贡献进社区仓库放 `packages/<name>`，包名 `@magpie-community/opencode-<name>-auth`，版本号推到 `main` 自动发布。GitHub 打 `magpie-plugin` topic 可进"非官方插件"列表（`package.json` 必须在仓库根目录，加载文件必须已提交——dist 只在发布时构建的仓库不显示）。

## 最小可用模板（API key + OpenAI 兼容）

一段完整可跑的骨架，真实插件的主要区别在登录方式和请求签名：

```js
// index.mjs
const PROVIDER = "acme"
const BASE = "https://api.acme.example/v1"

export const AcmeAuthPlugin = async ({ client }) => ({
  config: async (cfg) => {
    cfg.provider ??= {}
    // 默认值在前、用户已有配置在后：补齐缺省字段，但不覆盖用户改动
    const was = cfg.provider[PROVIDER] ?? {}
    cfg.provider[PROVIDER] = {
      name: "Acme",
      npm: "@ai-sdk/openai-compatible",   // 决定 fetch 收到的 API 格式
      api: BASE,
      models: { "acme-coder": { name: "Acme Coder", limit: { context: 200000, output: 32000 }, tool_call: true } },
      ...was,
    }
  },
  auth: {
    provider: PROVIDER,
    methods: [{ type: "api", label: "Acme API key", placeholder: "acme-…" }],
    async loader(getAuth) {
      const auth = await getAuth()
      if (auth?.type !== "api") return {}
      return {
        baseURL: BASE,
        apiKey: "opencode-acme-auth",     // 占位符！真 key 只进下面 fetch 的请求头（见「关键行为规则」）
        async fetch(input, init) {        // 每个请求都经过这里：签名、续期
          // 宿主会把这个 fetch 交给其他插件调用：只允许发往厂商自己的域名
          const url = new URL(String(input))
          if (url.origin !== new URL(BASE).origin) throw new Error(`${PROVIDER}: 拒绝把 key 发往 ${url.origin}`)
          const headers = new Headers(init?.headers)
          headers.set("authorization", `Bearer ${auth.key}`)
          return fetch(input, { ...init, headers })
        },
      }
    },
  },
})
```

## API 对照表（npm 字段 → fetch 收到的格式）

| `npm` | API | 基地址后的路径 |
|---|---|---|
| `@ai-sdk/anthropic`、`@ai-sdk/google-vertex/anthropic` | Anthropic Messages | `/messages` |
| `@ai-sdk/openai`、`@ai-sdk/azure` | OpenAI Responses | `/responses` |
| `@ai-sdk/google` | Gemini | `/models/<id>:streamGenerateContent?alt=sse` |
| `@ai-sdk/github-copilot` | GPT-5 及之后（gpt-5-mini 除外）用 Responses，其余 chat completions | `/responses` 或 `/chat/completions` |
| 其他（`@ai-sdk/openai-compatible`、`xai`、`groq`…） | Chat completions | `/chat/completions` |

基地址优先级：loader 的 `baseURL` → 模型的 `provider.api` → 供应商的 `api` → AI SDK 默认地址。请求体 `model` 是 API id（模型有 `id` 字段用它，否则用键名）。

## 钩子速查

| 钩子 | 归属 | 作用 | 关键约束 |
|---|---|---|---|
| `config(cfg)` | OpenCode | 声明供应商与默认模型 | 默认值在前、用户配置 spread 在后：补齐缺省字段但不覆盖用户改动 |
| `auth.methods` | OpenCode | 登录方式列表 | method 类型只有 `api`（key）和 `oauth`（url+callback，`method: "auto"` 自动完成 / `"code"` 用户粘贴）；method 上的 `prompts` 在登录前依次提问，问题类型 `text`/`select`/`password`（`password` 是 magpie 专属，OpenCode 只有前两种） |
| `auth.loader(getAuth)` | OpenCode | 每账号一次，返回 `baseURL`/`apiKey`/`headers`/`fetch` | 登录信息变化后重新运行；每账号作用域，状态按 auth 存，不放供应商级模块变量 |
| `provider.models(provider, {auth})` | OpenCode | 账号相关的模型列表 | 失败时返回 `provider.models` 或抛异常，magpie 保留原列表；登录失效抛 `{signIn: "expired"}` |
| `auth.usage(getAuth)` | **magpie** | 额度用量，显示在 `magpie quota` 与 `GET /v1/magpie/quotas` | 返回 `{plan, user, until, renew, balance, resets, windows:[{name, used, resetsAt 或 resetSecs, span, display, amount/limit/unit, model(s)/notModels, aside, runsOut*}], …}`，字段全可选；拉取失败返回 `{error, signIn: "kept"}` 降级，别抛异常把账号标成失效 |
| `auth.options` | **magpie** | 供应商编辑器里的开关卡片 | `[{key, label, description, default, confirm}]`，confirm 说明将发生的写操作（如"会创建令牌"）；截至 2026-10 官方文档仍未收录，以社区仓库为准 |
| `auth.refresh(auth)` | **magpie** | token 续期，magpie 统一调度 | 同一时间只续一次（refresh token 一次性也安全）；失败带 `signIn: "expired"`；OpenCode 忽略此钩子，fetch 里保留续期检查保兼容 |
| `auth.checkin(getAuth)` | **magpie** | 每日签到 | 返回 `{outcome: "claimed"/"done"/"ineligible"/…}`；**绝不自动解验证码**，返回 `captcha`。正式文档「签到」章节，需 v0.1.1083+；outcome 全集 claimed/done/ineligible/inactive/captcha/failed，可另带 credit/streak/message；2xx 但无可领是 done 不是 failed；返回表外值=failed，magpie 当天稍后再试 |
| `"chat.headers"(input, output)` | OpenCode | 每请求加头（会话/缓存头） | `input.sessionID` 同对话不变 |

## 关键行为规则

- **入口加载**：`exports["./server"]` → `main` → `exports["."]` → `index.ts/js/mjs/cjs`。**入口导出的每个函数都会被当作插件调用**——辅助函数别放入口，社区惯例 `export const _internal = {...}`。
- **多账号**：第一账号存供应商 id 下，其余 `id#xxxxxx`；用 `accountId`/`metadata.email`/`email` 命名，至少存一个。同 `accountId` 的登录替换原账号。API key 方式没有邮箱可拿：加一个 `prompts` 备注名提问（key 用 `email`，回答自动进 `metadata.email`），多账号时账号列表才分得清；不填退化为 key 尾几位。api 方式的 `authorize` 拿不到用户粘的 key（key 由宿主单独保存），登录时验证不了——坏 key 靠首次 models 拉取的 401 → `signIn: "expired"` 捕获，社区无先例可绕过。
- **协议/地址分流（单 provider 混多协议）**：托管混合模型（Claude+GPT+Gemini 之类）只需一个 provider。`models` 钩子返回的是 OpenCode Model 形状，分流用 **`api: { id, url, npm }`**（社区 zed/zcode 写法）；`provider: { npm, api }` 是 config 静态声明形状，写进 models 钩子不生效。动态清单生成的模型补齐 `status: "active"`、`cost`、`capabilities` 中性默认，避免宿主显示异常。
- **登录状态**：默认 401 标记账号、成功清除。用 `X-Magpie-Sign-In` 响应头精确控制：`expired`（拒绝登录）/ `kept`（这个 401 是别的问题）/ `renewed`（已续期）。
- **供应商 id 冲突**：id 被内置订阅/预设占用时自动变成 `<id>-plugin`；选一个只属于你的 id。
- **依赖**：`bun add` 安装、**不运行安装脚本**（依赖 postinstall 构建的包无法用）；Bun 的 `fetch`/`crypto`/`fs`/`$` 够用。可以调厂商 CLI（`$` 或 `child_process`），错误信息里说明未装时怎么办。
- **改模型 id 流量记账**：模型可写 `free: true`（不占额度）、`rate`（点数倍率，数字或 `"x0.5"`）、`rateWas`（优惠前倍率）；`status: "deprecated"` 的模型不显示。
- **服务档位**：models 钩子返回的模型可写 `serviceTiers`（如 ["priority","ultrafast"]）——写进 Codex 模型列表（priority 显示为 Fast）；Chat/Responses 请求选档时以 `service_tier` 到达 fetch；magpie 转协议的请求不会发出模型没列的档位。
- **并发上限**：`magpie.maxConcurrency`（package.json）或 `auth.maxConcurrency`（优先），1–1000，每账号同时请求数；用户在供应商上的设置优先。
- **插件更新**：@magpie-community/* 启动后与每小时自动更新；其他 npm 包出小圆点待用户确认（`magpie plugin update`）；`name@1.2.3` 固定版本不自动升；git 仓库按分支/标签指向的提交比对，固定到提交无更新。
- **同 id 双插件**：两个插件登录同一供应商 id 时只由一个提供（选定优先，否则后添加的优先）；`magpie plugin use <名字> <id>` 或在插件列表改选。
- **联网搜索透传**：转发 Anthropic/OpenAI 官方 API 时设 `searches: true`，客户端搜索请求原样到达你的 fetch。
- **决策 API**：给提供商设 `decide: true` + 模型 `decides: true`（config 或 models 钩子里写都行），模型可作为路由分类器（`POST {baseURL}/systemone`，请求体 {model, questions, state}）；标了 `decides` 的模型和名为 jev-* 的模型对智能体隐藏。
- **真 key 的边界（安全红线）**：loader 返回的 `apiKey` 只放固定占位符——宿主会把 loader options 共享给其他插件的 `chat.headers` 钩子，且 apiKey 为空时宿主自动从登录存档填充，真 key 绝不出现在这里；真 key 只在 `fetch` 里按请求注入请求头。同理 loader 的 `fetch` 必须校验目标 URL origin 是厂商域名：宿主可能把它交给其他插件调用，防止 key 被带去任意外部地址。
- **图标**：仓库根放 `icon.svg`（抓厂商官网 logo），`package.json` 的 `magpie.icon` 与各 `auth.icon` 用 `data:image/svg+xml;base64,…` 内嵌（不依赖外链，npm/GitHub 都能显示），icon.svg 加进 `files`。
- **本地单测先行**：沙箱 CLI 测试前先用 `node --test` 单测模拟宿主调用每个钩子（config 不覆盖、请求头注入、非厂商域名拒绝、401 → `signIn: "expired"`），配 `npm test` + GitHub Actions（setup-node 跑 `node --test test/*.test.mjs`）。
- **插件能看到的用户内容**：请求里的一切（对话、工具结果）。只发到用户要求的地方，不记日志。

## 其他插件形态（按需查全文档）

| 形态 | 声明 | 要点 |
|---|---|---|
| 网关中间件 | `"magpie": {"middleware": "./mw.js"}` 或 `*.middleware.js` 单文件 | **moejs 引擎运行（非 Bun）**：无 Node API/fetch/timer，只能相对导入、依赖打进文件；钩子 `onRequest`/`onProvider`/`onEvent`/`onResponse`（onProvider 按供应商尝试再调用，不能再拒/改路由）；选项 `ctx.options` 用 `magpie plugin options` 设；出错/超时按不存在处理；请求 250ms/事件 50ms/加载 1s；每秒热重载 |
| 路由策略/用量 | `*.gateway.js` 或 `"magpie": {"gateway": …}` | `strategies[name]` 返回座位顺序（20ms）；`onUsage` 收用量记录（250ms，异步不阻塞） |
| 异步网关请求钩子 | `"magpie": {"hooks": "./hooks.js"}` 或 `*.hooks.js` 单文件 | **Bun 运行**（非 moejs）：具名 async `onRequest(body, ctx)` 在路由前改 Agent 请求体（如注入召回上下文），可选 `onResponse` 尽力通知；改 model/stream/工具会被回滚算失败；默认 1s（`gatewayTimeoutMs` 100–10000），整链 2–10s；对所有供应商生效；纯网关插件不需要 main/exports |
| 工具插件 | OpenCode `tool` 钩子 + `@opencode-ai/plugin` | 组成 magpie 的 MCP 服务器 `/mcp/magpie/tools`；工具名 `<插件>_<工具>`；单工具 55s 超时 |
| Agent 插件 | `"magpie": {"agent": "./agent.js"}` 或 `*.agent.js` | 声明 Agent 配置文件位置与模型键，`connect({gateway, model, models, agent})` 返回要写入的键（gateway 有 url/v1/key，model 含 native_endpoints 与 pricing）；moejs 运行；与内置 Agent 同 id 会被拒；资源库 `library: {instructions, mcp, mcpFormat, skills}`——写 mcp 必须写 mcpFormat，否则拒绝加载 |
| 窗口页面 | `"magpie": {"page": {"title", "file", "icon"}}` | 纯 HTML/CSS/JS 沙盒 iframe：无 fetch/内联脚本，`magpie.read()` 只能读 `permissions` 声明的（`usage:summary`、`providers:list`）；可 `replaces` 内置页面（sessions/library/routing/usage）、往自带页面加 `panels`（slot: agents/usage/settings/provider，最多 8 个）、加 `actions` 右键菜单项（最多 8 个）；`page.titles` 多语言 |
| pi 扩展包 | `pi.registerProvider` 注册供应商 | 不用改直接用；登录走 pi 的 onPrompt/onAuth |

## 失败模式速查（症状 → 修复）

| 症状 | 原因与修复 |
|------|-----------|
| 供应商叫 `…-plugin` | id 被内置订阅占用；换独占 id，或该插件是社区替代弃用内置订阅的例外（用内置 id） |
| 辅助函数被当插件运行 | 入口导出的每个函数都被调用；辅助函数移出入口或挂到 `_internal` |
| 依赖 postinstall 的包装不上 | magpie 不运行安装脚本；改成预构建产物或打包进入口 |
| 账号互相串状态 | loader/usage 每账号作用域运行；状态按 auth 存（如 `client.auth.set`），不放供应商级变量 |
| token 过期反复登出 | 加 `auth.refresh`（refreshLead 默认 5 分钟）；OpenCode 兼容场景在 fetch 里保留续期检查 |
| 401 误标登录失效 | 该 401 是别的问题时，fetch 返回头 `X-Magpie-Sign-In: kept` |
| 模型列表拉取失败全丢 | models 钩子失败时返回 `provider.models` 原样兜底；登录失效抛 `{signIn: "expired"}` |
| 模型分流写了 `provider: {npm, api}` 不生效 | 那是 config 声明形状；`models` 钩子返回的 Model 要用 `api: { id, url, npm }` |
| 多账号在列表里分不清 | api 方式无邮箱：加 `prompts` 备注名（key 用 `email`）存 `metadata.email` 命名 |
| 拉用量失败把账号标成失效 | usage 钩子返回 `{error, signIn: "kept"}` 降级；仍失败查网络/代理后重试；还不行挂 `aside` 型窗口别硬标失效 |
| 其他插件能读到你的 API key | loader 的 `apiKey` 放了真 key：改固定占位符，真 key 只进 fetch 请求头 |
| loader 的 fetch 把 key 发到别的域名 | 宿主会把它交给其他插件调用：fetch 里校验目标 origin 是厂商域名，不是就抛错 |
| 中间件钩子不生效 | 检查运行环境限制（moejs：无 Node API；事件 50ms 超时）；`events` 导出只对有名字的事件 API 有效，Chat/Gemini 别写 |
| 在应用里改了代码没生效 | 应用内把插件关掉再打开（终端命令每次都按当前内容加载） |
| npm 发布后插件搜不到 | keywords 缺失：搜索查 `<关键词> opencode`，keywords 必须含 `opencode` + `auth`/`plugin`/`provider` 之一 |
| 页面插件 `magpie.read()` 被拒 | `magpie.permissions` 未声明该读取；只能声明 `usage:summary`、`providers:list`，其余一律拒绝 |
| 两个插件登录同一个 id 只有一个生效 | 选定的优先，否则后添加的优先；`magpie plugin use <名字> <id>` 改选，另一行会写明由谁提供 |
| npm 包不自动更新 | 固定版本（name@1.2.3）停在原版本；`magpie plugin update` 装最新并取消固定；@magpie-community/* 才自动更新 |
| Agent 插件不加载、提示 library | library 写了 mcp 必须同时写 mcpFormat（alma/claude/codex/… 之一），mcpFormat 不在列表也拒绝 |
| 异步 hooks 不生效/报失败 | 超时默认 1s（查 `gatewayTimeoutMs` 100–10000ms 与整链预算 2–10s），或改了 model/stream/工具选择——都会回滚算失败：onRequest 只做请求体增强（如注入上下文），fetch 用 ctx.signal；仍失败看设置 → 插件的失败计数 |
| `magpie plugin use` 提示找不到插件 | 同 id 双插件按名字/spec/短名定位；先 `m plugin --json` 看两个包各自由谁提供；仍不行卸载多余的那个 |
| 签到 outcome 总是 failed | 返回了表外 outcome 或抛异常；2xx 但无可领要回 `done` 不是 failed；验证码回 `captcha` 绝不自动解；仍失败查账号作用域（getAuth 拿的是本账号）|
| 面板/页面空白或显示已停止工作 | panels slot 只能 agents/usage/settings/provider；高度跟随 <html>（最高 2400px），别给 html/body 固定高度；10 秒内无应答判停 |

以上之外，实现纪律类红线见「反例黑名单」。

## 反例黑名单（不要做）

以下为实现纪律红线（与「失败模式速查」互补：那里是症状排查，这里是禁止项）：

| # | 不要做 | 后果/替代 |
|---|--------|----------|
| 1 | 把用户对话内容发到第三方或写日志 | 只发到用户要求的地方 |
| 2 | 自动解决签到验证码 | 返回 `outcome: "captcha"` 让用户手动 |
| 3 | config 钩子直接赋值覆盖 provider | 用 `??=`，否则覆盖用户 plugins.json 配置 |
| 4 | 从入口 export 默认对象后又导出函数 | 二选一：`export default {id, server}` 或纯函数导出 |
| 5 | GitHub 插件仓库 dist 只在发布时构建 | GitHub 直装按仓库当前代码加载，文件必须已提交 |
| 6 | 给 pi/中间件/Agent 包写运行时依赖（社区贡献） | 社区规范：除非确实需要，零运行时依赖 |
| 7 | Agent 插件占用内置 Agent id（codex/claude…） | 会被拒绝；插件是添加不是替换 |
| 8 | 在入口文件导出辅助函数 | 每个导出函数都被当插件调用；用 `_internal` |
| 9 | 依赖 postinstall 安装脚本 | magpie 不运行安装脚本；预构建或打包 |
| 10 | 在用户日常 magpie 上直接调试 | 用沙箱 HOME（`mktemp -d` + 独立 `XDG_*`） |
| 11 | 状态存供应商级模块变量 | 多账号互相污染；按 auth 作用域存 |
| 12 | 中间件里用 Node API / fetch / 定时器 | moejs 引擎不支持；依赖打进文件、相对导入 |
| 13 | loader 的 `apiKey` 放真 key | 宿主共享给其他插件、空时自动从存档填充；放占位符，真 key 只进 fetch 请求头 |
| 14 | loader 的 fetch 不校验目标域名 | 它会被宿主交给其他插件调用；origin 不是厂商域名就抛错 |
| 15 | 异步 hooks 里改 model/stream/工具选择 | 回滚算失败，该请求不再调 onResponse；onRequest 只做增强 |
| 16 | Agent 插件 id 用内置 Agent 名（codex/claude…） | 已在黑名单 #7；library.mcp 不配 mcpFormat 同样拒绝加载 |
| 17 | 给页面/面板的 html 或 body 设固定高度 | 面板高度跟随 <html>（≤2400px），固定高度显示截断 |

## 使用说明

- 本 skill 是决策与骨架参考；钩子的完整字段、usage 返回结构、宿主协议、pi 细节查 [references/plugin-doc-full.md](references/plugin-doc-full.md) 对应章节。
- 实现前先看社区同名或同厂商的插件（[magpie-community/plugins](https://github.com/magpie-community/plugins)）有没有现成登录逻辑可参考；社区仓库的 `bun scripts/check.mjs <name>` 可离线校验钩子。
- **单文件全功能范例**：[egenchen/magpie-packycode](https://github.com/egenchen/magpie-packycode)——key 占位符、fetch 域名防护、config 合并、动态模型、usage 卡片（失败降级 `signIn: "kept"`）、`auth.options` 开关卡片（含 confirm）、多 key 故障转移、node --test + CI，UI/交互写法看它一个文件够了。
- **登录状态/多账号/多协议分流范例**：社区仓库 packages/zed（`api: {id, url, npm}`）、packages/zcode（`X-Magpie-Sign-In: kept` 包装、usage 窗口换算）、packages/packycode 同仓库路径（多 key 故障转移）；API key 多账号备注名同见 zcode/packycode。
- **Agent skill 形态的范例**：[magpie-quota](references/example-magpie-quota-skill.md) 是社区官方 skill（让 agent 查额度/等待恢复），展示了好的 skill 写法——frontmatter description 只写触发条件、命令+JSON 结构速查、"Don't" 黑名单收尾、明确 exit codes。给 magpie 生态写 skill（社区仓库 `skills/<name>/SKILL.md`）或写插件时可参照它的结构与克制。
- references/plugin-doc-full.md 已更新为 2026-10-26 抓取的最新官方文档（含签到、异步网关请求钩子、onProvider、panels、serviceTiers、actions/replaces、更新机制）；`auth.refresh` 需 v0.1.684+，`auth.checkin` 需 v0.1.1083+（文档示例标注 v0.1.676）。
