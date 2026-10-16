---
name: write-magpie-plugin
description: Use when 为 magpie（usemagpie.ai）编写供应商插件、把某个 AI 套餐/订阅接入 magpie、写 OpenCode provider plugin、排查插件加载失败或登录不工作、实现 auth/usage/refresh 钩子、发布插件到 npm 或 magpie-community、写网关中间件或工具插件。触发词：magpie、opencode plugin、provider plugin、auth loader、X-Magpie-Sign-In、magpie-community。
---

# Magpie 插件开发

为 magpie（usemagpie.ai）编写供应商插件：登录某个 AI 服务、替它发请求，使它成为 magpie 的供应商。magpie 运行 OpenCode v1 供应商插件，为 OpenCode 写的插件不用改就能用；magpie 专属钩子（`auth.usage`、`auth.refresh`、`auth.checkin`、`magpie.*` 字段）OpenCode 会忽略，一个包可以同时服务两边。

**核心原则：插件 = 一个 async 函数返回一组钩子；先分清"OpenCode 标准"与"magpie 专属"，再动手。**

完整 API 细节查 [references/plugin-doc-full.md](references/plugin-doc-full.md)（官方文档全文）；现成参考实现见 [magpie-community/plugins](https://github.com/magpie-community/plugins)（cline、cursor、zed、grok、zcode 等 20+ 个，含审核标准）。

## 开发工作流

1. **确认接入形态**（三问）：
   - 登录方式？API key（`type: "api"`）/ 浏览器或设备码（`type: "oauth"` + `authorize` 返回 url+callback）。
   - 模型走什么 API？见下方「API 对照表」，决定 `npm` 字段。
   - 模型列表是静态还是账号相关？静态写 `config` 钩子；账号相关加 `provider.models` 钩子。
2. **建包**：`package.json`（`"type": "module"`，入口 `index.mjs` 或 `index.ts`，keywords 含 `opencode`+`opencode-plugin`+`<厂商>`）+ 入口文件导出一个 async 函数。
3. **实现钩子**（最小集）：`config`（声明供应商，用 `??=` 防覆盖用户配置）→ `auth`（methods + loader）→ 按需 `provider.models`、`auth.usage`、`auth.refresh`。
4. **沙箱测试**（绝不在日常 magpie 上测）：

   ```bash
   sb=$(mktemp -d)
   m() { env HOME=$sb XDG_CONFIG_HOME=$sb/.config XDG_CACHE_HOME=$sb/.cache MAGPIE_ADDR=127.0.0.1:3499 magpie "$@"; }
   m plugin add ./<插件目录>   # 文件夹就地加载
   m plugin --json             # 方式、账号、模型、加载错误
   m plugin login <id>         # 每种方式、每个提问
   m provider test <id>        # 每种 API 发一个小请求
   m quota                     # usage 钩子
   ```
5. **发布**：npm 照常发布（搜索靠 keywords：`opencode` + `auth`/`plugin`/`provider` 之一）；想进推荐列表给 [magpie-community/plugins](https://github.com/magpie-community/plugins) 的 `registry.json` 提 PR（需 `name`、`providers`、`icon`、双语 `summary`）；贡献进社区仓库放 `packages/<name>`，包名 `@magpie-community/opencode-<name>-auth`，版本号推到 `main` 自动发布。GitHub 打 `magpie-plugin` topic 可进"非官方插件"列表（`package.json` 必须在仓库根目录，加载文件必须已提交——dist 只在发布时构建的仓库不显示）。

## 最小可用模板（API key + OpenAI 兼容）

一段完整可跑的骨架，真实插件的主要区别在登录方式和请求签名：

```js
// index.mjs
const PROVIDER = "acme"
const BASE = "https://api.acme.example/v1"

export const AcmeAuthPlugin = async ({ client }) => ({
  config: async (cfg) => {
    cfg.provider ??= {}
    cfg.provider[PROVIDER] ??= {          // ??= 防止覆盖用户在 plugins.json 的配置
      name: "Acme",
      npm: "@ai-sdk/openai-compatible",   // 决定 fetch 收到的 API 格式
      api: BASE,
      models: { "acme-coder": { name: "Acme Coder", limit: { context: 200000, output: 32000 }, tool_call: true } },
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
        async fetch(input, init) {        // 每个请求都经过这里：签名、续期
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
| `@ai-sdk/anthropic` | Anthropic Messages | `/messages` |
| `@ai-sdk/openai`、`@ai-sdk/azure` | OpenAI Responses | `/responses` |
| `@ai-sdk/google` | Gemini | `/models/<id>:streamGenerateContent?alt=sse` |
| 其他（`@ai-sdk/openai-compatible`、`xai`、`groq`…） | Chat completions | `/chat/completions` |

基地址优先级：loader 的 `baseURL` → 模型的 `provider.api` → 供应商的 `api` → AI SDK 默认地址。请求体 `model` 是 API id（模型有 `id` 字段用它，否则用键名）。

## 钩子速查

| 钩子 | 归属 | 作用 | 关键约束 |
|---|---|---|---|
| `config(cfg)` | OpenCode | 声明供应商与默认模型 | 用 `cfg.provider ??=`，别覆盖用户配置 |
| `auth.methods` | OpenCode | 登录方式列表 | `api`（key）；`oauth`（url+callback，`method: "auto"` 自动完成 / `"code"` 用户粘贴）；`password` 类型是 magpie 专属 |
| `auth.loader(getAuth)` | OpenCode | 每账号一次，返回 `baseURL`/`apiKey`/`headers`/`fetch` | 登录信息变化后重新运行；每账号作用域，状态按 auth 存，不放供应商级模块变量 |
| `provider.models(provider, {auth})` | OpenCode | 账号相关的模型列表 | 失败时返回 `provider.models` 或抛异常，magpie 保留原列表；登录失效抛 `{signIn: "expired"}` |
| `auth.usage(getAuth)` | **magpie** | 额度用量，显示在 `magpie quota` | 返回 `{plan, windows:[{name, used, resetsAt, span}], …}`，字段全可选 |
| `auth.refresh(auth)` | **magpie** | token 续期，magpie 统一调度 | 同一时间只续一次（refresh token 一次性也安全）；失败带 `signIn: "expired"`；OpenCode 忽略此钩子，fetch 里保留续期检查保兼容 |
| `auth.checkin(getAuth)` | **magpie** | 每日签到 | 返回 `{outcome: "claimed"/"done"/"ineligible"/…}`；**绝不自动解验证码**，返回 `captcha` |
| `"chat.headers"(input, output)` | OpenCode | 每请求加头（会话/缓存头） | `input.sessionID` 同对话不变 |

## 关键行为规则

- **入口加载**：`exports["./server"]` → `main` → `exports["."]` → `index.ts/js/mjs/cjs`。**入口导出的每个函数都会被当作插件调用**——辅助函数别放入口，社区惯例 `export const _internal = {...}`。
- **多账号**：第一账号存供应商 id 下，其余 `id#xxxxxx`；用 `accountId`/`metadata.email`/`email` 命名，至少存一个。同 `accountId` 的登录替换原账号。
- **登录状态**：默认 401 标记账号、成功清除。用 `X-Magpie-Sign-In` 响应头精确控制：`expired`（拒绝登录）/ `kept`（这个 401 是别的问题）/ `renewed`（已续期）。
- **供应商 id 冲突**：id 被内置订阅/预设占用时自动变成 `<id>-plugin`；选一个只属于你的 id。
- **依赖**：`bun add` 安装、**不运行安装脚本**（依赖 postinstall 构建的包无法用）；Bun 的 `fetch`/`crypto`/`fs`/`$` 够用。可以调厂商 CLI（`$` 或 `child_process`），错误信息里说明未装时怎么办。
- **改模型 id 流量记账**：模型可写 `free: true`（不占额度）、`rate`（点数倍率）。
- **联网搜索透传**：转发 Anthropic/OpenAI 官方 API 时设 `searches: true`，客户端搜索请求原样到达你的 fetch。
- **决策 API**：给提供商设 `decide: true` + 模型 `decides: true`，模型可作为路由分类器（`POST {baseURL}/systemone`）；标了 `decides` 的模型对智能体隐藏。
- **插件能看到的用户内容**：请求里的一切（对话、工具结果）。只发到用户要求的地方，不记日志。

## 其他插件形态（按需查全文档）

| 形态 | 声明 | 要点 |
|---|---|---|
| 网关中间件 | `"magpie": {"middleware": "./mw.js"}` 或 `*.middleware.js` 单文件 | **moejs 引擎运行（非 Bun）**：无 Node API/fetch/timer，只能相对导入、依赖打进文件；钩子 `onRequest`/`onEvent`/`onResponse`；出错/超时按不存在处理；请求 250ms/事件 50ms |
| 路由策略/用量 | `*.gateway.js` 或 `"magpie": {"gateway": …}` | `strategies[name]` 返回座位顺序（20ms）；`onUsage` 收用量记录（250ms，异步不阻塞） |
| 工具插件 | OpenCode `tool` 钩子 + `@opencode-ai/plugin` | 组成 magpie 的 MCP 服务器 `/mcp/magpie/tools`；工具名 `<插件>_<工具>`；单工具 55s 超时 |
| Agent 插件 | `"magpie": {"agent": "./agent.js"}` 或 `*.agent.js` | 声明 Agent 配置文件位置与模型键，`connect({gateway, model})` 返回要写入的键；moejs 运行；与内置 Agent 同 id 会被拒 |
| 窗口页面 | `"magpie": {"page": {"title", "file", "icon"}}` | 纯 HTML/CSS/JS 沙盒 iframe：无 fetch/内联脚本，`magpie.read()` 只能读 `permissions` 声明的（`usage:summary`、`providers:list`） |
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
| 中间件钩子不生效 | 检查运行环境限制（moejs：无 Node API；事件 50ms 超时）；`events` 导出只对有名字的事件 API 有效，Chat/Gemini 别写 |
| 在应用里改了代码没生效 | 应用内把插件关掉再打开（终端命令每次都按当前内容加载） |

## 反例黑名单（不要做）

| # | 不要做 | 后果/替代 |
|---|--------|----------|
| 1 | 在入口文件导出辅助函数 | 每个导出函数都被当插件调用；用 `_internal` |
| 2 | 依赖 postinstall 安装脚本 | magpie 不运行安装脚本；预构建或打包 |
| 3 | 在用户日常 magpie 上直接调试 | 用沙箱 HOME（`mktemp -d` + 独立 `XDG_*`） |
| 4 | 状态存供应商级模块变量 | 多账号互相污染；按 auth 作用域存 |
| 5 | 把用户对话内容发到第三方或写日志 | 只发到用户要求的地方 |
| 6 | 自动解决签到验证码 | 返回 `outcome: "captcha"` 让用户手动 |
| 7 | config 钩子直接赋值覆盖 provider | 用 `??=`，否则覆盖用户 plugins.json 配置 |
| 8 | 中间件里用 Node API / fetch / 定时器 | moejs 引擎不支持；依赖打进文件、相对导入 |
| 9 | 从入口 export 默认对象后又导出函数 | 二选一：`export default {id, server}` 或纯函数导出 |
| 10 | GitHub 插件仓库 dist 只在发布时构建 | GitHub 直装按仓库当前代码加载，文件必须已提交 |
| 11 | 给 pi/中间件/Agent 包写运行时依赖（社区贡献） | 社区规范：除非确实需要，零运行时依赖 |
| 12 | Agent 插件占用内置 Agent id（codex/claude…） | 会被拒绝；插件是添加不是替换 |

## 使用说明

- 本 skill 是决策与骨架参考；钩子的完整字段、usage 返回结构、宿主协议、pi 细节查 [references/plugin-doc-full.md](references/plugin-doc-full.md) 对应章节。
- 实现前先看社区同名或同厂商的插件（[magpie-community/plugins](https://github.com/magpie-community/plugins)）有没有现成登录逻辑可参考；社区仓库的 `bun scripts/check.mjs <name>` 可离线校验钩子。
- 内容基于 magpie v0.1.676+ 文档（2026-10 抓取）；`auth.refresh` 需 v0.1.684+，`auth.checkin` 需 v0.1.1083+。
