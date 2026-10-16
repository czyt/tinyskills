目录插件开发

文档 · 插件

# 编写插件

插件负责登录某个服务、替它发请求。magpie 把插件变成一个供应商，所有 agent 都能用，多账号、故障切换、用量这些也都有。magpie 运行的是 [OpenCode 的供应商插件](https://opencode.ai/docs/plugins/)，为 OpenCode 写的插件不用改就能在这里用；注册了供应商的 [pi](https://github.com/earendil-works/pi) 扩展包也能直接用（见 [pi 扩展包](https://usemagpie.ai/docs/zh/plugins#pi)）。本页讲插件作者需要知道的：magpie 调用哪些钩子、拿到返回值后做什么，以及怎么测试、发布和上架插件。

**一段话说清楚。** 插件是一个 npm 包、一个 git 仓库或一个文件夹。它的模块导出一个 async 函数，形式是 OpenCode v1 插件。magpie 把所有插件加载进同一个 [Bun](https://bun.sh/) 进程，也就是 _插件宿主_。函数返回一组钩子：


- `config` 声明供应商和它的默认模型。
- `auth` 给出登录方式，以及一个 `loader`，由它的 `fetch` 发出每个请求。
- `provider.models` 列出某个账号有哪些模型。
- `auth.usage` 说明套餐用了多少。这是 magpie 自己的钩子，OpenCode 会忽略它。
- `auth.refresh` 在账号的 token 过期前续期，同一时间只续一次。它也是 magpie 自己的钩子。

agent 用什么 API 发来都可以。网关把请求转成模型使用的 API（chat completions、Responses、Anthropic Messages 或 Gemini），交给插件的 `fetch`，再把回答流式传回去。

## [五分钟写一个插件](https://usemagpie.ai/docs/zh/plugins\#quick)

这个例子登录 Acme，一个虚构的编程套餐。Acme 用 API key 登录，接口兼容 OpenAI，并能报告每个账号的模型和用量。真实的插件主要区别在于怎么登录、怎么给请求签名。整个例子已在 magpie v0.1.676 和本地模拟的 Acme API 上跑通。

package.json复制

```
{
  "name": "opencode-acme-auth",
  "version": "0.1.0",
  "description": "OpenCode provider plugin: Acme Coding Plan",
  "type": "module",
  "main": "./index.mjs",
  "files": ["index.mjs", "README.md"],
  "keywords": ["opencode", "opencode-plugin", "acme"],
  "license": "MIT",
  "magpie": { "maxConcurrency": 4 }
}
```

index.mjs复制

```
const PROVIDER = "acme"
const BASE = "https://api.acme.example/v1"

export const AcmeAuthPlugin = async ({ client }) => ({
  // 供应商，以及还没人登录时它有的模型
  config: async (cfg) => {
    cfg.provider ??= {}
    cfg.provider[PROVIDER] ??= {
      name: "Acme",
      npm: "@ai-sdk/openai-compatible", // chat completions
      api: BASE,
      models: {
        "acme-coder": { name: "Acme Coder", limit: { context: 200000, output: 32000 }, tool_call: true },
      },
    }
  },

  auth: {
    provider: PROVIDER,
    methods: [{ type: "api", label: "Acme API key", placeholder: "acme-…" }],
    // 这个账号的每个请求带上什么
    async loader(getAuth) {
      const auth = await getAuth()
      if (auth?.type !== "api") return {}
      return {
        baseURL: BASE,
        async fetch(input, init) {
          const headers = new Headers(init?.headers)
          headers.set("authorization", `Bearer ${auth.key}`)
          headers.set("x-acme-client", "opencode-acme-auth/0.1.0")
          return fetch(input, { ...init, headers })
        },
      }
    },
    // magpie 自己的钩子：套餐用了多少
    async usage(getAuth) {
      const auth = await getAuth()
      const res = await fetch(`${BASE}/usage`, { headers: { authorization: `Bearer ${auth.key}` } })
      if (!res.ok) return { error: `Acme answered ${res.status}`, windows: [] }
      const u = await res.json()
      return {
        plan: u.plan,
        windows: [{ name: "5 hours", used: u.percent, resetsAt: u.resets_at, span: 5 * 3600 }],
      }
    },
  },

  // 向 Acme 查询这个账号有哪些模型
  provider: {
    id: PROVIDER,
    async models(provider, { auth } = {}) {
      if (auth?.type !== "api") return provider.models
      const res = await fetch(`${BASE}/models`, { headers: { authorization: `Bearer ${auth.key}` } })
      if (!res.ok) return provider.models // magpie 保留原来的列表
      const { data } = await res.json()
      const base = provider.models["acme-coder"]
      return Object.fromEntries(data.map((m) => [m.id, { ...base, id: m.id, name: m.name ?? m.id }]))
    },
  },
})
```

把文件夹加到 magpie，登录，然后试一下：

终端复制

```
magpie plugin add ./opencode-acme-auth   # 文件夹就地加载，不安装任何东西
magpie plugin login acme                 # 询问 key
magpie plugin                            # acme (Acme, 2 models)  signed in
magpie provider test acme                # ✓ chat  7 ms · acme-coder
magpie quota                             # acme · Pro · 5h 37% ↻59m
```

现在 agent 可以用 `acme/acme-coder` 访问它的模型，和其他供应商的模型一样。在应用里，打开插件，点添加插件，填入文件夹路径，再在这个供应商那一行登录。

**在沙箱里试。** 正在写的插件不应碰到你真正在用的 magpie。给 magpie 一个单独的 `HOME`，做法见 [测试](https://usemagpie.ai/docs/zh/plugins#test)。

## [magpie 如何运行插件](https://usemagpie.ai/docs/zh/plugins\#run)

- **Bun。** 第一次添加插件时，magpie 会下载 Bun，所有插件都跑在它上面。Bun 能直接运行 TypeScript，所以入口可以是 `index.ts`。
- **一个宿主进程。** 所有开着的插件都加载进同一个 Bun 进程，第一次用到时启动。magpie 和宿主通过 stdin、stdout 通信，每行一条 JSON 消息。插件打印的任何内容，包括 `console.log` 和 `process.stdout`，都会被转到 stderr，magpie 以 `plugin: …` 记进日志。
- **安装。**
  - npm 包用 `bun add` 安装，不运行安装脚本，和 OpenCode 安装插件的方式一样。依赖 `postinstall` 构建的包无法使用。
  - git 仓库由 Bun 拉取：`github:owner/repo[#ref]`、`git+https://…` 或 `owner/repo`。
  - 文件夹或文件的路径就地加载。
- **重启。** 添加、移除、更新、开关插件都会重启宿主。还在通过旧宿主流式返回的回答会先完成。终端里每条 `magpie` 命令都启动自己的宿主，所以文件夹插件总是按当前内容加载。在应用里，把插件关掉再打开即可加载你的修改。
- **代理。** 插件为某个供应商或账号发出的每个 fetch，都走用户给这个供应商或账号设置的代理；没有设置就走 magpie 自己的代理，除非设成 _直连_。回环地址从不走代理。自己传了 `proxy` 选项的 fetch 不会被改动。
- **更新。**
  - 社区的包（`@magpie-community/*`）在 magpie 启动后不久自动更新，之后每小时一次。
  - 其他包有新版本时，插件上会出现一个小圆点，用户点一下或运行 `magpie plugin update` 更新。
  - 固定了版本的写法（`name@1.2.3`）会停在那个版本，直到用户自己更新：更新到 …、全部更新和 `magpie plugin update` 会装上最新版并取消固定。
  - git 仓库没有版本号可比。它的分支或标签（不写 `#ref` 时是默认分支）指向的提交和 Bun 装的那个不一样时，才显示有更新：GitHub 上的通过 GitHub API 查询，其他主机用 `git ls-remote`，最多每十分钟问一次，每小时的检查也会再问。固定到某个提交的写法不会有更新。这一行会显示已安装的提交。

magpie 在它的配置目录（`~/.config/magpie` 或 `$XDG_CONFIG_HOME/magpie`）里保存这些：

| 文件 | 内容 |
| --- | --- |
| `plugins.json` | 已添加的插件：`{"plugins": [{"spec", "off"?, "options"?}], "config"?}`。`options` 是插件的第二个参数，和 OpenCode 的 `["name", {…}]` 一样。`config` 是交给插件的 OpenCode 配置。 |
| `plugins/` | 已安装的 npm 和 git 包，是一个独立的 Bun 项目。 |
| `plugin-auth.json` | 登录信息（权限 600），格式和 OpenCode 的 `auth.json` 相同，所以登录可以在两者之间迁移。 |
| `plugin-providers.json` | 插件上次列出的供应商和模型，magpie 启动时不必再问插件。 |

## [包的结构](https://usemagpie.ai/docs/zh/plugins\#package)

### magpie 从哪里加载

magpie 查找插件服务端入口的位置和 OpenCode 一样，加载第一个导出了插件的文件：

1. `package.json` 里的 `exports["./server"]`，然后 `main`，然后 `exports["."]`（`exports` 是字符串时就用它）。
2. 否则是 `index.ts`、`index.tsx`、`index.js`、`index.mjs` 或 `index.cjs`。

路径指向单个文件时，就加载那个文件。

### 模块导出什么

- `export default { id, server }`（OpenCode v1）：`server` 就是插件。
- 否则， **模块导出的每个函数** 都会被当作插件调用，导出的 `{ server }` 对象也一样。

所以不要从入口文件导出辅助函数。测试需要的东西放在一个对象上，社区插件的做法是 `export const _internal = { … }`。

### 插件函数

形式

```
async (input, options) => hooks
// input:   { client, project, directory, worktree, serverUrl, $, experimental_workspace }
// options: plugins.json 中这一项的 "options"，没有则为 undefined
// hooks:   { config?, auth?, provider?, "chat.headers"? }
```

导出多个函数，一个插件就能提供多个供应商，每个函数的钩子互不相干。两个插件为同一个供应商提供了 `auth` 钩子时，后加载的生效，和 OpenCode 一样。

### package.json 里 magpie 的字段

OpenCode 会忽略 `magpie` 对象，所以给 OpenCode 插件加上它是安全的。

| 字段 | 含义 |
| --- | --- |
| `magpie.icon` | 插件自己的图标，用在「发现」里的卡片（从 npm 读取，GitHub 上的插件从仓库读取）和「已安装」里的那一行；没有自己图标的供应商也用它：`https://` 地址或 `data:image/…` URI，最大 1 MB，SVG、PNG 等都行。 |
| `magpie.maxConcurrency` | 每个账号同时接多少个请求，1 到 1000 的整数。用户在供应商上设置的上限优先。 |

同样的字段也可以写在 `auth` 钩子上（`auth.icon`、`auth.maxConcurrency`），优先于 `package.json`。一个插件登录多个供应商时，可以给每个供应商各写一个 `auth.icon`，`magpie.icon` 留给插件本身。

## [供应商与模型](https://usemagpie.ai/docs/zh/plugins\#provider)

### 声明供应商

供应商的 id 就是 `auth.provider`。如果 [models.dev](https://models.dev/) 收录了这个 id，magpie 会以那里的条目为起点，和 OpenCode 一样。否则就在 `config` 钩子里声明供应商。用 `??=`，以免覆盖用户在 `plugins.json` 里配置的供应商：

config 钩子

```
config: async (cfg) => {
  cfg.provider ??= {}
  cfg.provider["acme"] ??= {
    name: "Acme",
    npm: "@ai-sdk/anthropic",          // 模型使用的 API（见下表）
    api: "https://api.acme.example/v1", // 请求发往哪里，除非 loader 另有指定
    models: {
      "acme-large": {
        name: "Acme Large",
        id: "acme-large-2026-09",          // API 接受的 id，和键不同时填
        limit: { context: 400000, output: 64000 },
        reasoning: true,
        tool_call: true,
        modalities: { input: ["text", "image"] },
        cost: { input: 3, output: 15, cache_read: 0.3 }, // 每百万 token 的美元价格；套餐可不填
        variants: { low: {}, medium: {}, high: {} },        // 推理档位
      },
    },
  }
}
```

模型还可以写 `provider: { npm, api }`，使用和供应商不同的 API 或地址；也可以写 `headers`、`options`，以及用 `disabled: true` 隐藏它。

### 自己能联网搜索的上游

如果插件转发的是 Anthropic 或 OpenAI 官方 API（它们自己执行托管的联网搜索工具），在 `config` 钩子里给提供商设 `searches: true`。之后客户端的联网搜索（Claude Code 的 WebSearch、Codex 的 `web_search`）会原样发到你的 `fetch`，只作用于该提供商走 Anthropic 或 Responses 的模型，不再经过 magpie 自己的代搜；Chat 模型不受影响。magpie 不会自动用它替其他模型搜索，但可以在设置里手动指定它为搜索模型。

### 决策 API（System One）

插件可以为自己的提供商提供 TypeSafe 的 System One API，这样它的模型就能当 [路由组的分类器](https://usemagpie.ai/docs/zh/intent)。在 `config` 钩子里给提供商设 `decide: true`，并给每个只回答问题、不用来对话的模型设 `decides: true`（写在 `config` 钩子里或 `models` 钩子的列表上都行）。之后 magpie 会把每个问题以 `POST {baseURL}/systemone` 发给 loader 的 `fetch`，带上账号的登录信息，和其他请求一样。请求体是 `{"model", "questions", "state"}`；回答 `{"model", "answers": {"<问题>": {"choice", "score", "confidence"}}}`。

标了 `decides` 的模型，以及名为 `jev-*` 的模型，会作为分类器提供，并对智能体隐藏：发给它的对话请求会被拒绝。提供商没有 `decide: true` 时，`decides` 不起作用，所有模型照常用于对话。

### 模型使用的 API

模型或供应商上 `npm` 指定的 AI SDK 包决定了 API，也就决定了你的 `fetch` 收到的请求格式。无论 agent 发来的是什么，magpie 的网关都已经转换好了：

| npm | API | 基地址后的路径 |
| --- | --- | --- |
| `@ai-sdk/anthropic`、`@ai-sdk/google-vertex/anthropic` | Anthropic Messages | `/messages` |
| `@ai-sdk/openai`、`@ai-sdk/azure` | OpenAI Responses | `/responses` |
| `@ai-sdk/google` | Gemini | `/models/<id>:streamGenerateContent?alt=sse` |
| `@ai-sdk/github-copilot` | GPT-5 及之后（gpt-5-mini 除外）用 Responses，其余用 chat completions | `/responses` 或 `/chat/completions` |
| 其他（`@ai-sdk/openai-compatible`、`xai`、`groq`、`deepseek` 等） | Chat completions | `/chat/completions` |

基地址按这个顺序选：

1. loader 的 `baseURL`；
2. 模型的 `provider.api`；
3. 供应商的 `api`；
4. AI SDK 包自己的默认地址（`https://api.anthropic.com/v1`、`https://api.openai.com/v1` 等）。

请求体里的 `model` 是模型的 API id：有 `id` 就用它，否则用键名。

### 每个账号的模型

模型因账号而异时，加一个 `provider` 钩子：

provider 钩子

```
provider: {
  id: "acme",
  async models(provider, { auth }) {
    // provider.models：models.dev 和 config 钩子给出的模型，以 id 为键
    // auth：这个账号的登录信息，和 plugin-auth.json 中保存的一样
    return { "acme-large": { ...provider.models["acme-large"], name: "Acme Large" } }
  },
}
```

- magpie 为每个账号调用一次，在这个账号的作用域里、经过它的代理。每个账号只承接为它列出的模型，所以低档套餐的账号不会收到它没有的模型。
- 模型是 OpenCode 的 `Model`：


  - `id`、`name`；
  - `api: {id, url, npm}`；
  - `limit: {context, input?, output}`；
  - `capabilities: {reasoning, toolcall, attachment, input: {text, image, …}}`；
  - `cost: {input, output, cache: {read, write}}`；
  - `variants`、`release_date`、`status`。

 最省事的做法是展开 `provider.models` 里的模型，再改几个字段。`status` 为 `"deprecated"` 的模型不会显示。
- magpie 还会读取模型上的这些字段，OpenCode 会忽略它们：
  - `free: true`：套餐免费提供，不占额度。
  - `rate`：一次请求消耗的点数倍率，可以是数字（`0.5`），也可以照厂商的写法（`"x0.5"`）。
  - `rateWas`：当前优惠之前的倍率。
 模型选择器会显示它们。
- 模型支持推理时，`variants` 的键会成为它的推理档位。

### 连不上厂商时

钩子出现以下任一情况，magpie 都会保留原有的列表，和内置订阅拉取列表失败时一样：

- 请求失败后原样返回 `provider.models`；
- 抛出异常；
- 返回自己的列表，并设置 `list[Symbol.for("magpie.fellBack")] = true`。

如果失败的原因是登录失效，就抛出带 `signIn: "expired"` 的错误，这个账号会被标记为需要重新登录（见 [登录状态](https://usemagpie.ai/docs/zh/plugins#signin-state)）。

## [登录](https://usemagpie.ai/docs/zh/plugins\#signin)

`auth` 钩子的形式是 `{ provider, methods, loader, usage?, refresh?, refreshLead?, icon?, maxConcurrency? }`。每个 method 是用户可选的一种登录方式。在应用里它们是按钮；在终端里，`magpie plugin login <id> [<method>]` 会询问选哪个。

### API key

api 方式

```
{ type: "api", label: "Acme API key", placeholder: "acme-…" }
```

- `label` 是 key 输入框的标题。只写“API key”的会显示成“Acme API key”。
- `placeholder` 是 magpie 自己的字段，显示在输入框里作提示。
- 没有 `authorize` 函数时，key 原样保存：`{type: "api", key, metadata?}`。`prompts` 的回答放在 `metadata` 里。
- 有 `authorize(inputs)` 时，由插件自己校验或换取 key，返回 `{type: "success", key, metadata?}` 或 `{type: "failed", error?}`。

### 浏览器或设备码登录

oauth 方式

```
{
  type: "oauth",
  label: "Sign in with Acme",
  async authorize(inputs) {
    const d = await startDeviceCode()
    return {
      url: d.verification_uri,                    // magpie 打开它
      instructions: `Enter the code ${d.user_code}`, // 并显示这段说明
      method: "auto",                              // "auto"：callback() 自己完成
      async callback() {                           // "code"：callback(code)，用户粘贴的码
        const t = await pollForToken(d)
        if (!t) return { type: "failed", error: "The code expired" }
        return { type: "success", refresh: t.refresh_token, access: t.access_token,
                 expires: Date.now() + t.expires_in * 1000, accountId: t.email }
      },
    }
  },
}
```

- 带 `refresh` 的成功结果保存为 `{type: "oauth", refresh, access, expires, …}`，你返回的其他字段（`accountId`、`enterpriseUrl`、你自己的字段）都一并保存。
- 带 `key` 的成功结果保存为 API key。
- 结果里写 `provider: "other-id"`，登录就保存到插件负责的另一个供应商下。
- 失败结果里的 `error` 是 magpie 自己的字段：用户会看到原因（最多 500 字符）。不写的话，用户只能看到登录失败。
- 只有带 `prompts` 的方式才会收到 `inputs`。没有 prompts 的方式收到 `undefined`，和 OpenCode 的 TUI 一样。OpenCode 的 CLI 传的是空对象，有些插件因此会在终端里自己提问。

### 登录前的提问

method 的 `prompts` 在 `authorize` 之前依次提问，每一项只在条件成立时出现：

prompts

```
prompts: [\
  { type: "select", key: "region", message: "Region",\
    options: [{ label: "Global", value: "global" }, { label: "China", value: "cn", hint: "acme.cn" }] },\
  { type: "text", key: "team", message: "Team id", placeholder: "t-…",\
    when: { key: "region", op: "eq", value: "global" },        // 或 condition: (inputs) => boolean\
    validate: (v) => (/^t-/.test(v) ? undefined : "Starts with t-") },\
]
```

`type: "password"` 的问题和 `text` 一样，只是输入时不显示：应用里是掩码输入框，终端里的 `magpie plugin login` 不回显。适合 token、个人访问令牌（PAT）。这是 magpie 自己的类型，OpenCode 只有 `text` 和 `select`。

### 账号

- **保存位置。** 一个供应商可以登录多次。第一个账号保存在供应商 id 下，和 OpenCode 一样；其他账号保存在 `id#xxxxxx` 下。
- **用户怎么区分它们。** magpie 依次用 `accountId`、`metadata.email`、`email` 给账号命名。至少保存其中一个，能拿到邮箱就用邮箱。
- **重新登录。** 新的登录和已有账号 `accountId` 相同时，会替换那个账号。如果两边都有 `uid`（厂商自己的 id，用于名字可能重复的厂商），它也必须相同。没有 id 时，比较密钥是否相同。都不匹配就成为新账号。
- **作用域。** magpie 为某个账号发起的每次调用，都在这个账号的作用域里运行：

  - `getAuth()` 返回这个账号。
  - `client.auth.set({ path: { id: "acme" }, body })` 保存到这个账号。
 所以每个账号的状态要按拿到的 auth 来保存，不要放进以供应商为键的模块变量。
- **刷新。** 提供 `auth.refresh`，magpie 就会替你续期（见 [续期登录](https://usemagpie.ai/docs/zh/plugins#renew)）。否则 token 过期时，在 `fetch` 里刷新，再用 `client.auth.set` 保存完整对象。你给的内容会替换原有内容，不做合并。

### 续期登录

从 magpie 0.1.684 起，插件可以用 `auth.refresh` 把 token 续期交给 magpie。这是 magpie 自己的钩子（OpenCode 会忽略它）：

auth 钩子

```
auth: {
  provider: "acme",
  methods: [ … ],
  // 可选：在 expires 之前多久续期（毫秒），默认 5 分钟
  refreshLead: 5 * 60 * 1000,
  async refresh(auth, provider) {  // auth 是这个账号保存的登录信息
    const t = await exchange(auth.refresh)
    if (t.error === "invalid_grant")
      throw Object.assign(new Error("Acme 拒绝了登录"), { signIn: "expired" })
    return { access: t.access_token, refresh: t.refresh_token ?? auth.refresh,
             expires: Date.now() + t.expires_in * 1000 }
  },
  loader: async (getAuth) => ({ … }),  // getAuth() 拿到的已经是续期后的 token
}
```

- **什么时候运行。** OAuth 账号的 `expires` 距现在不到 `refreshLead` 时，在这个账号的 loader、`provider.models`、`auth.usage` 或请求之前运行。`expires` 为 0 或没有的账号不会续期。
- **同一时间只续一次。** 发现 token 快过期的请求会一起等同一次续期，所以只允许 refresh token 用一次的厂商不会收到两次。最多等 15 秒；超时的续期在完成时照样保存。
- **保存什么。** 你返回的字段会覆盖账号原有的同名字段（会合并，这点和 `client.auth.set` 不同），账号的标记也会清除。没什么可续的就什么都不返回。
- **失败时。** 账号保持原样，请求带着旧 token 继续发，由厂商的回答来说明结果。带 `signIn: "expired"` 的错误会标记账号（见 [登录状态](https://usemagpie.ai/docs/zh/plugins#signin-state)），重新登录之前 magpie 不再尝试。其他错误 30 秒后再试。
- **OpenCode 和旧版 magpie。** 它们会忽略这个钩子。如果插件也要在那里运行，`fetch` 里的检查请保留：在 magpie 下它会发现 token 是新的，什么也不做。

## [请求](https://usemagpie.ai/docs/zh/plugins\#requests)

`loader(getAuth, provider)` 每个账号运行一次，账号登录信息变化后会重新运行。它返回 OpenCode 会交给 AI SDK 的内容：

| 字段 | magpie 怎么用 |
| --- | --- |
| `baseURL` | 请求发往的地址，优先于模型和供应商的 `api`。 |
| `apiKey` | 按 AI SDK 包的方式发送：Anthropic 用 `x-api-key`，Google 用 `x-goog-api-key`，其他用 `Authorization: Bearer`。API key 登录时默认就是保存的 key。 |
| `headers` | 加到每个请求上。 |
| `fetch` | 发出请求。不提供时，magpie 的宿主用标准 `fetch`。 |

你的 `fetch(input, init)` 收到的请求：

- `input` 是完整 URL：基地址加上模型 API 对应的路径。
- `init.method` 通常是 `POST`。
- `init.headers`按下面的顺序设置，后面的覆盖前面的：

  1. `apiKey` 对应的 key 头；
  2. loader 的 `headers`；
  3. 网关请求的头；
  4. `chat.headers` 钩子加的头。
- `init.body` 是这种 API 格式的 JSON 字符串（不是 UTF-8 文本时为字节）。其中的 `model` 是 API id，`stream` 照 agent 的要求。
- `init.signal` 在 agent 放弃请求时中止。

返回一个 `Response`。它的状态码、头和正文原样传回，正文逐块流式传输。如果你改写了流式正文，要去掉头里的 `content-length` 和 `content-encoding`。

### 失败与故障切换

- 非 2xx 的响应就是厂商的回答，网关会像对待其他供应商一样处理：限流或服务端错误会把请求转到下一个账号或模型，401 会标记账号（见 [登录状态](https://usemagpie.ai/docs/zh/plugins#signin-state)）。
- 抛出异常会让请求失败，然后故障切换继续。
- 尽量用该 API 自己的错误格式回答，这样 agent 会显示厂商的原话。

### chat.headers

OpenCode 的 `chat.headers` 钩子对每个请求都会运行。它的 `input.sessionID` 是 magpie 的会话 id，在同一段对话的各轮之间保持不变。可以用它填厂商的会话头或缓存头：

chat.headers

```
"chat.headers": async (input, output) => {
  if (input.model.providerID === "acme") output.headers["x-acme-session"] = input.sessionID
}
```

## [登录状态](https://usemagpie.ai/docs/zh/plugins\#signin-state)

厂商拒绝了某个账号的登录时，magpie 会给它打上标记，告诉用户，并且在它恢复之前不再往它发请求。默认情况下，401 打标记，成功清除标记。插件可以用 `X-Magpie-Sign-In` 响应头更准确地说明一个回答的含义，magpie 会在转发前去掉这个头：

| 值 | 含义 |
| --- | --- |
| `expired` | 登录被拒绝，无论状态码是什么（有些厂商为此返回 403 或 502）。 |
| `kept` | 账号保持原样（这个 401 说的是别的问题）。 |
| `renewed` | 登录已续期：清除标记，无论请求接下来遇到什么。 |

在 `fetch` 或 `provider.models` 里，抛出带 `signIn: "expired"` 的错误效果相同：

index.mjs

```
throw Object.assign(new Error("Acme refused the sign-in; sign in again"), { signIn: "expired" })
```

## [用量](https://usemagpie.ai/docs/zh/plugins\#usage)

`auth.usage(getAuth, provider)` 是 magpie 自己的钩子，说明一个账号的额度用了多少。它在账号的作用域里运行，所以它刷新的 token 会保存到这个账号。magpie 把结果显示在供应商里的账号上、`magpie quota` 里，以及网关的 `GET /v1/magpie/quotas`。所有字段都可选：

usage 返回值

```
{
  plan: "Pro",
  user: "ada@example.com",     // 厂商那边的账号名
  until: "2026-11-01T00:00:00Z", // 套餐到期时间
  renew: "auto",                // 或 "off"
  balance: "$12.40",
  error: "",                    // 显示在额度窗口的位置
  windows: [{\
    name: "5 hours",\
    used: 37,                   // 百分比；超用时大于 100\
    resetsAt: "2026-10-03T18:00:00Z", // 或 resetSecs: 3600\
    span: 18000,                // 窗口长度，单位秒\
    display: "370 / 1000 credits",\
    amount: 370, limit: 1000, unit: "credits", // 按数量计时，窗口自己的用量\
    model: "opus",              // 只统计 id 含这个词的模型\
    models: [], notModels: [],  // 或恰好这些 id，或除这些外的全部\
    aside: false,               // true：用完也不影响账号使用\
    runsOutAt: "2026-10-05T00:00:00Z", runsOut: 120, // 剩余额度中最早作废的一笔何时作废、作废多少\
  }],
  resets: { count: 2, until: "…", byWindow: false, fiveHour: 1, weekly: 1 }, // 账号可用的重置次数
  signIn: "kept",               // 同 X-Magpie-Sign-In
}
```

时间可以是 ISO 字符串，也可以是以秒或毫秒为单位的时间戳。没有 `signIn` 时，提示要重新登录的 `error` 会标记账号，一次正常读取会清除标记。

## [插件能拿到什么](https://usemagpie.ai/docs/zh/plugins\#input)

magpie 交给插件的是 OpenCode `PluginInput` 里的内容，只要它在没有 OpenCode 服务端时还有意义：

| 字段 | 在 magpie 里 |
| --- | --- |
| `client.auth.set` / `.remove` | 保存或删除当前作用域账号的登录信息。 |
| `client.app.log` | 写入 magpie 的日志，格式为 `plugin [level]: [service] message`。 |
| `client.tui.showToast` | 写入 magpie 的日志。 |
| `client.config.get` | 所有插件的 `config` 钩子运行之后的配置。 |
| 其他 `client.*` | 返回 `{ data: undefined }`。 |
| `directory`、`worktree` | magpie 的配置目录，可以在这里存文件。 |
| `project` | `{ id: "magpie", worktree }`。 |
| `$` | Bun 的 shell。 |
| `serverUrl` | 占位值，后面没有 OpenCode 服务端。 |

magpie 调用的钩子是 `config`、`auth`（它的 methods、`loader` 和 `usage`）、`provider.models` 和 `chat.headers`。插件的其他钩子（`tool`、`event`、`chat.params` 等）不会被调用，工具由 agent 自己运行。

## [供应商 id](https://usemagpie.ai/docs/zh/plugins\#ids)

- agent 用 `<id>/<model>` 指代插件的模型，id 就是插件的 `auth.provider`。
- 这个 id 在 magpie 里已被占用时，比如内置订阅、预设（`google`、`openai`、`anthropic` 等）或 `magpie` 本身，插件的供应商会叫 `<id>-plugin`。请选一个只属于你的 id。
- 社区为 magpie 已弃用的内置订阅做的插件是例外。它们用内置订阅的 id（`cursor`、`zed` 等），用户迁移到插件后就接管这个 id，agent 无需任何改动。
- 两个已安装的插件登录同一个 id 时（比如已发布的插件和你自己的副本），只由其中一个提供：选定的那个，否则是后添加的那个。两个插件都留在插件 → 已安装里，各自那一行会写明由哪个提供。在另一行点用于 …，或运行 `magpie plugin use <名字> <id>`，即可改选。

## [测试](https://usemagpie.ai/docs/zh/plugins\#test)

在沙箱里运行 magpie，这样你自己的 magpie、agent 和登录信息都不会被碰到：

终端复制

```
sb=$(mktemp -d)
m() { env HOME=$sb XDG_CONFIG_HOME=$sb/.config XDG_CACHE_HOME=$sb/.cache MAGPIE_ADDR=127.0.0.1:3499 magpie "$@"; }
m plugin add ./opencode-acme-auth </dev/null
m plugin --json                     # 插件列出的内容：方式、账号、模型、加载错误
m plugin login acme                 # 每种方式、每个提问
m provider test acme                # 每种 API 发一个很小的请求
m provider test acme acme-coder     # 或只测指定的模型
m quota                             # usage 钩子
m plugin logout acme
```

- 加载失败的插件，在 `magpie plugin` 里会说明原因。
- 钩子的错误和插件打印的内容都在输出里，以 `plugin: …` 开头。
- 单元测试用 `bun test`，测试你放在 `_internal` 上的函数。
- [社区仓库](https://github.com/magpie-community/plugins) 里有几个脚本：

  - `bun scripts/check.mjs` 像 magpie 一样加载每个包，并检查它的钩子。
  - `scripts/try.sh <name>` 在上面那样的沙箱里运行它。

## [发布与上架](https://usemagpie.ai/docs/zh/plugins\#publish)

- **npm。** 照常发布。用户可以按名字添加（`magpie plugin add opencode-acme-auth`），按版本（`…@0.2.0`），从 git，或从文件夹。
- **搜索。** 插件里的搜索会向 npm 查询 `<关键词> opencode`，显示名字或 keywords 里同时含有 `opencode` 和 `auth`、`plugin`、`provider` 之一的包。keywords 写成 `["opencode", "opencode-plugin", "<厂商>"]` 就可以。它还会查询 `keywords:pi-package <关键词>`，显示名字或 keywords 里提到 `auth` 或 `provider` 的 pi 扩展包。
- **README。** 插件在 magpie 里的详情页显示它在 npm 上的 README。写清楚它登录什么、怎么登录、登录信息存在哪里、有哪些模型。
- **推荐列表。** 插件页推荐的是社区仓库 [`registry.json`](https://github.com/magpie-community/plugins/blob/main/registry.json) 里的插件。magpie 最多每六小时拉取一次，并内置一份副本，拉不到时使用。想被收录，就提一个 PR 加上一项：

  registry.json

  ```
  { "package": "opencode-acme-auth", "name": "Acme", "icon": "https://acme.example/icon.svg",
    "providers": ["acme"],
    "summary": { "en": "Your Acme Coding Plan.", "zh": "使用你的 Acme Coding Plan。" } }
  ```



   中间件的条目写 `"kind": "middleware"`，不写 `providers`，列在网关中间件下。其他类型也一样：`"kind": "tools"` 列在给 Agent 的工具下，`"kind": "page"` 列在页面下，`"kind": "agent"` 列在 Agent 下。`MAGPIE_PLUGIN_MARKET=<url>` 让 magpie 改用另一份列表，可以用来检查你的条目；设为 `off` 则只用内置副本。
- **GitHub 标签。** 在 GitHub 上打了 `magpie-plugin` topic 的仓库，会显示在 插件 → 发现 → 非官方插件 · GitHub 里，Star 多的在前，并标明没有人审阅过。`package.json` 要放在仓库根目录。发布到 npm 且 `repository` 指向这个仓库的，从 npm 安装；否则按仓库当前的代码安装，所以它加载的文件必须提交进仓库：`dist` 只在发布时才构建的仓库不会显示。fork、已归档的仓库和 magpie-community 自己的仓库也不显示。magpie 最多每十分钟问一次 GitHub，仓库打上标签后几分钟内就会出现。卡片显示 `package.json` 里 `"magpie": { "icon": "…" }` 给的图标，没有就显示拼图图标。
- **社区包。** 想把插件贡献到 [magpie-community/plugins](https://github.com/magpie-community/plugins)：

  - 放在 `packages/<name>` 下，包名为 `@magpie-community/opencode-<name>-auth`（供应商）、`@magpie-community/middleware-<name>`（中间件或路由策略）、`@magpie-community/tools-<name>`（工具）、`@magpie-community/page-<name>`（页面）或 `@magpie-community/agent-<name>`（Agent），除非确实需要，不要有运行时依赖。
  - 把版本号的改动推到 `main` 就会发布。
  - 这些包在每个 magpie 里都会自动更新。

## [网关中间件](https://usemagpie.ai/docs/zh/plugins\#middleware)

插件还可以是 _网关中间件_：agent 发给 magpie 网关的每个请求，在路由之前先经过它；回复在返回的路上也经过它。它可以给模型起别名、往系统提示词里加内容、拒绝请求、改写或隐藏模型说的话，或者自己统计经过的流量。它对所有供应商都起作用，不管是不是插件提供的。

alias.middleware.js复制

```
// alias.middleware.js
export const events = ["message_start"]

export function onRequest(body, ctx) {
  ctx.state.asked = body.model
  if (body.model === "fast") body.model = "deepseek/deepseek-chat"
  if ((ctx.options.blocked ?? []).includes(body.model)) return ctx.reject(403, "not this model")
  return body
}

export function onEvent(ev, ctx) {
  ev.message.model = ctx.state.asked  // the agent sees the name it asked for
  return ev
}
```

shell复制

```
magpie plugin add ./alias.middleware.js   # 或者 package.json 里写了 "magpie": { "middleware": "./mw.js" } 的包
```

### [现成的中间件](https://usemagpie.ai/docs/zh/plugins\#middleware-community)

社区仓库里有现成的中间件可以直接添加，大多是 [New API](https://github.com/QuantumNous/new-api) 为渠道提供的功能，用的也是同样的 JSON。它们在插件 → 发现 → 网关中间件里，那里每张卡片都标明它是供应商还是中间件。

| 包 | 作用 |
| --- | --- |
| [`param-override`](https://github.com/magpie-community/plugins/tree/main/packages/param-override) | New API 的参数覆盖（`param_override`）：设置、删除、移动、复制或改写请求里的字段，可以只对某些模型或在满足条件时生效，也可以拒绝请求。从 New API 复制来的 `param_override` 不用改。 |
| [`model-map`](https://github.com/magpie-community/plugins/tree/main/packages/model-map) | New API 的模型重定向（`model_mapping`）：把一个模型换成另一个名字发出，按名字或 `/正则/`。回复里仍是 agent 请求的模型名。 |
| [`system-prompt`](https://github.com/magpie-community/plugins/tree/main/packages/system-prompt) | 给每个请求（或只给某些 agent、某些模型）加上你的系统提示词，放在各个 API 自己的位置。请求自带系统提示词时保留原样，除非打开 `override`。 |
| [`word-guard`](https://github.com/magpie-community/plugins/tree/main/packages/word-guard) | New API 的敏感词过滤：用户发送的内容里出现所列词语或正则时拒绝或打码，也可以对回复打码。 |
| [`think-tags`](https://github.com/magpie-community/plugins/tree/main/packages/think-tags) | 去掉回复正文开头的 `<think>…</think>`，或把 Chat 回复的 `reasoning_content` 放进正文（New API 的 `thinking_to_content`）。 |

shell复制

```
magpie plugin add @magpie-community/middleware-model-map
magpie plugin options model-map '{"mapping": {"fast": "deepseek/deepseek-chat"}}'
```

### [选项](https://usemagpie.ai/docs/zh/plugins\#middleware-options)

中间件从 `ctx.options` 读取设置，也就是 `plugins.json` 里它那一项的 `options`。可以在插件 → 已安装里点中间件的选项按钮，在它那一行里以 JSON 编辑；也可以用 `magpie plugin options <名字> '<json>'`（`off` 清除）。名字可以是包名、spec 或短名：`@magpie-community/middleware-model-map` 的短名是 `model-map`。从下一个请求起生效。包可以在 `package.json` 里用 `"magpie": { "options": { … } }` 给出建议的选项：没有设置时编辑框以它为起点，但在你保存之前，中间件运行时没有选项。

### 运行方式

中间件不在 Bun 里运行，而是在网关自己的进程里，用 Go 写的 JavaScript 引擎 [moejs](https://github.com/Calcium-Ion/moejs) 运行。原因是一个回复会流式传输成千上万个事件，每个事件都要等它处理完。在一个事件上调用一次钩子大约耗时 1 微秒，而和 Bun 往返一次要几十微秒。每个中间件只编译一次，每个请求有自己的运行时，所以请求之间可以并行，同一个请求的各个钩子共享 `ctx.state`。

- **声明方式。** 在 `package.json` 里写 `"magpie": { "middleware": "./mw.js" }`，或者用一个名为 `*.middleware.js`（或 `.mjs`）的单文件。没有 `main` 也没有 `exports` 的包只是中间件，插件宿主不会加载它；两者都有的包既是供应商插件，也是中间件。
- **导入。** 只能用相对路径导入插件目录里的文件。这里没有 `node_modules`，用到的依赖请打包进文件。
- **能用什么。** 标准 JavaScript 和 `console.log`（写进 magpie 的日志，每分钟最多 60 行）。没有定时器、没有 `fetch`，也没有 Node API。钩子可以是 `async` 的，但没有什么可等待的。
- **修改后。** magpie 每秒检查一次这些文件和 `plugins.json`，有变化就重新加载中间件。

### 钩子

每个钩子是一个具名导出，或者 `export default { … }` 的一个成员。请求体和事件都是 agent 自己的 API 格式（`ctx.protocol`），不是供应商的。返回要继续发送的对象；什么都不返回，就按原样发送。

| 钩子 | 拿到的内容 | 返回 |
| --- | --- | --- |
| `onRequest(body, ctx)` | 路由之前的请求体：改了 `model`，请求就会路由到别处。 | 请求体，或者不返回。`ctx.reject(status, message)` 会拒绝这个请求，并用 agent 的 API 格式返回这个错误（不给状态码时是 403）。 |
| `onEvent(event, ctx)` | 流式回复里的每个事件：它的 `data:` JSON。 | 事件、不返回，或者 `null` 表示丢掉这个事件。 |
| `onResponse(body, ctx)` | 非流式的完整回复；`ctx.status` 是它的状态码。 | 回复体，或者不返回。 |

`export const events = ["content_block_delta"]` 让 `onEvent` 只处理这些名字的事件（Anthropic Messages 和 Responses 的事件有名字）。Chat Completions 和 Gemini 的事件没有名字，处理它们时不要写 `events`。一个事件只是回复的一小段，一个词可能被拆在两个事件里。`data: [DONE]` 行和注释直接放行，不经过钩子。压缩过的回复原样放行。

`ctx` 里有 `protocol`（`anthropic`、`chat`、`responses` 或 `gemini`）、agent 请求的 `model` 和 `stream`、`path`、magpie 知道时的 `agent`、`options`（这个插件的 [选项](https://usemagpie.ai/docs/zh/plugins#middleware-options)），以及 `state`：每个请求独有的对象。

### 钩子出错时

处理请求或完整回复时，钩子有 250 毫秒；处理一个事件时有 50 毫秒；加载有 1 秒。钩子抛出异常、超时或返回了别的东西，都当作它不存在：请求或事件按原样发送。设置 → 插件会显示每个中间件的钩子、调用次数、平均每次耗时和失败次数，以及最近一次错误。钩子看到的是 agent 发出和收到的原始内容：发出时在 magpie 脱敏之前，返回时在还原之后。magpie 自己的请求（会话标题、路由分类器）不经过中间件。

### [路由与用量记录](https://usemagpie.ai/docs/zh/plugins\#gateway-points)

同一个模块还可以导出 `strategies` 和 `onUsage`。这样的文件可以命名为 `*.gateway.js`，包里也可以写 `"magpie": { "gateway": "./gw.js" }`。

- **路由。** 每个 `strategies[name]` 是一个名为 `<插件>/<name>` 的路由（插件包的短名，或去掉 `.gateway.js` 的文件名），插件开着时，供应商、号池和分组的路由选择里都会列出它。它是函数 `(pool, seats, options)`，或带 `order` 的对象，返回尝试各个座位的顺序（下标）。每个座位有 `key`、`account`、`known`、`learns`、`used`、`soon`（额度窗口何时刷新，毫秒）、`pace`、`weight`、`resting` 和 `tokens`（最近发给它的量）。它有 20 ms；出错、超时或返回别的东西时，按列表顺序尝试。插件关掉后，用它的供应商或分组也按列表顺序。
- **用量。**`onUsage(row, options)` 在每个请求结束后拿到它的用量记录：供应商、账号和密钥、模型、token、`ms`、`ttftMs`、状态、错误类型和费用，不含请求体、提示词或错误文本。它单独运行，请求从不等它；它忙到队列满时到来的记录会被丢弃并计数。它有 250 ms。

spread.gateway.js复制

```
// spread.gateway.js
export const strategies = {
  "fewest-tokens": (pool, seats) =>
    seats.map((_, i) => i).sort((a, b) =>
      (seats[a].resting - seats[b].resting) || (seats[a].tokens - seats[b].tokens)),
}

let slow = 0

export function onUsage(row, options) {
  if (row.ms > (options.slowMs ?? 30000)) {
    slow++
    console.log(`slow: ${row.provider} ${row.model} ${row.ms} ms (${slow} so far)`)
  }
}
```

shell复制

```
magpie plugin add ./spread.gateway.js
magpie group set fast routing=spread/fewest-tokens
```

## [给每个智能体的工具](https://usemagpie.ai/docs/zh/plugins\#tools)

插件可以用 OpenCode 的 `tool` 钩子提供工具，magpie 把它们提供给每个智能体，不只是 OpenCode：它们组成 magpie 自己的一个 MCP 服务器，地址是 `/mcp/magpie/tools`（Streamable HTTP）。把这个地址加到任何支持 MCP 服务器的智能体里，它的模型就能调用你已开启的插件提供的每个工具。每个工具名为 `<插件>_<工具>`，插件的短名在前，例如下面的 `weather-tools_now`。

index.js复制

```
import { tool } from "@opencode-ai/plugin"

export const WeatherTools = async () => ({
  tool: {
    now: tool({
      description: "某个城市现在的天气。",
      args: { city: tool.schema.string().describe("城市，例如 Berlin") },
      async execute({ city }, ctx) {
        const r = await fetch(`https://wttr.in/${encodeURIComponent(city)}?format=3`, { signal: ctx.abort })
        return await r.text()  // 文本；对象会以 JSON 发回
      },
    }),
  },
})
```

shell复制

```
magpie plugin add ./weather-tools
claude mcp add --transport http magpie-tools http://127.0.0.1:3425/mcp/magpie/tools   # Claude Code；其他智能体填同一个地址
```

设置 → 插件里会按这些名字列出每个插件的工具，并能复制服务器地址。`args` 可以是 zod 字段表（`tool.schema` 就是 zod）、zod 对象或 JSON Schema 对象。智能体会看到它，magpie 在 `execute` 运行前按它检查调用的参数；参数不对时回一个写明是哪个参数的错误。`ctx` 与 OpenCode 的相同，`agent` 是发起调用的智能体。每个工具最多运行 55 秒，到时 `ctx.abort` 触发。

这个服务器由内置插件 插件工具 提供。只要有已开启的插件提供工具，它就保持开启；关闭时不列出任何工具，调用会说明它已关闭。用网关密钥发起的调用计入该密钥的限额。工具和提供方插件一样，以你的权限在插件宿主里运行，结果只回给调用它的智能体。

## [Agent 插件](https://usemagpie.ai/docs/zh/plugins\#agents)

插件还可以添加一个 _Agent_：magpie 没有内置接入的那种。它说明这个 Agent 把模型写在哪里，以及还要写些什么才能让 Agent 走 magpie 的网关。这样它就和 magpie 内置的 Agent 一样出现在 Agent 页：在它那一行选一个 magpie 的模型，magpie 就把模型连同网关地址和这个 Agent 自己的 key 写进它的配置；关掉开关，一切恢复成用户原来的样子。下面的例子添加 [Aider](https://aider.chat/)。

agent.js复制

```
// agent.js，由 package.json 里的 "magpie": { "agent": "./agent.js" } 指定
export const agent = {
  id: "aider", name: "Aider", bin: "aider",
  config: "~/.aider.conf.yml",  // magpie 修改的文件
  model: "model",                 // 文件里模型的键
  prefix: "openai/",              // 写在 magpie 模型 id 前面
  ua: ["aider", "litellm"],
  notice: "Aider reads its settings when it starts: restart it to use the new model.",
}

export function connect({ gateway, model }) {
  return {
    "openai-api-base": gateway.v1,
    "openai-api-key": gateway.key,
    "show-model-warnings": false,
  }
}
```

shell复制

```
magpie plugin add ./agent-aider   # 也可以是单个 *.agent.js 文件
```

### agent 导出

| 字段 | 含义 |
| --- | --- |
| `id` | Agent 页、用量和命令行里用的 id：小写字母、数字、`.`、`_` 和 `-`。和 magpie 内置 Agent 相同的 id（`codex`、`claude` 等）会被拒绝：插件是添加 Agent，不是替换。 |
| `name` | 页面上显示的名字。不写就用 id。 |
| `config` | magpie 修改的文件。会展开 `~` 和 `$VAR`。文件不存在时会新建。 |
| `format` | `json`、`yaml` 或 `env`，文件名看不出格式时才需要写（`.json`/`.jsonc`、`.yaml`/`.yml`、`.env`）。暂不支持 TOML。 |
| `model` | 文件里模型的键，JSON 和 YAML 用点分路径（`llm.model`）。模型在 Agent 自己里面选（从 `connect` 写入的模型里挑，比如 Raycast）时不写它：这一行就只有连接开关、没有模型选择器，而 `connect`（这种插件必须有）调用时不带 `model`。 |
| `prefix` | 写在 magpie 模型 id 前面的内容：通过 LiteLLM 访问 OpenAI 兼容接口的 Agent 用 `openai/`。id 本身是网关接受的 `<供应商>/<模型>`。 |
| `bin`、`dir` | `PATH` 上的命令和配置目录，用来判断 Agent 是否已安装。 |
| `ua` | Agent 的 User-Agent 里的词，请求没带它的 key 时，用来在用量里认出它。 |
| `icon` | 这一行的图标：图标名、`https://` 或 `data:` URL。不写就用插件自己的图标，再没有就用通用图标。 |
| `notice` | 换模型之后显示的提示，和内置 Agent 一样。 |
| `library` | Agent 从哪里读资源库给它的东西：`instructions`（每次对话前读的 Markdown 文件）、`mcp`（它的 MCP 服务器文件）和 `mcpFormat`（这个文件的写法跟哪个 Agent 的一样：`alma`, `antigravity`, `claude`, `cline`, `codex`, `commandcode`, `copilot`, `crush`, `cursor`, `devin`, `gemini`, `goose`, `grok`, `hermes`, `kimi`, `omp`, `opencode`, `zed`；`claude` 即 `{"mcpServers": {…}}`），以及 `skills`（放 `SKILL.md` 文件夹的目录）。每项都可省略，`~` 和 `$VAR` 会展开：`library: { instructions: "~/.toy/AGENTS.md", mcp: "~/.toy/mcp.json", mcpFormat: "claude", skills: "~/.toy/skills" }`。不写的话，资源库不会给它任何东西，给它某一项时会被拒绝，并说明插件该写哪个键。 |

### connect

`connect(input)` 返回要在模型旁边一起写入的其他键，按键路径给出各自的值；可以是 `async`。它拿到 `gateway`（`url`、`v1`——以 `/v1` 结尾的地址——和 `key`，即这个 Agent 自己的 key，请求会按它的 id 计入用量）、`model`（`id`、`name`、`context`、`output`、`images`、`efforts`）、`models`（magpie 给这个 Agent 的所有模型，格式相同）和 `agent`（`id`、`config`）。没有 `connect` 的插件只写模型。magpie 的模型有变化时会再调用一次 `connect`，它写的模型列表因此保持最新。

### magpie 怎么用它

- **写入。** 每个键原地修改，用户的注释和其他键都保留。第一次写之前，每个键原来的值会按原类型存起来（数字仍是数字）。
- **恢复。** 重新选回 Agent 自己的模型，或关掉开关，每个键都恢复原值，原来没有的键会被删掉。文件从不整体覆盖。
- **是否已接入。** 只要存 magpie key 的那个键还是这个 key，这一行就显示已接入。之后手动改过的键会在这一行里指出，和内置 Agent 一样。
- **运行方式。** 和 [中间件](https://usemagpie.ai/docs/zh/plugins#middleware) 一样：在 magpie 自己的进程里用 moejs 运行，只能导入插件内的文件，没有 Node API，`console.log` 进 magpie 的日志。加载和 `connect` 各有一秒。模块加载失败或 `connect` 抛错的插件，会在插件页它那一行写明原因，并且什么都不写入。
- **资源库。** 写了 `library`，这个 Agent 就和内置 Agent 一样拿到资源库的内容：指令写在文件里 magpie 的两行标记之间，MCP 服务器和用户自己的写在同一个文件里（用户自己加的字段保留），技能以链接或副本放进文件夹。取消时只拿走 magpie 写的部分，文件原来的内容留在 magpie 的备份里。`mcpFormat` 不在列表中，或写了 `mcp` 却没写 `mcpFormat`，插件不会加载。
- **声明方式。**`package.json` 里写 `"magpie": { "agent": "./agent.js" }`，或者一个名为 `*.agent.js`（或 `.mjs`）的单文件。一个包可以同时是供应商、中间件和 Agent。插件市场里 Agent 条目写 `"kind": "agent"`，列在 Agent 下；社区包命名为 `@magpie-community/agent-<name>`。

## [窗口里的页面](https://usemagpie.ai/docs/zh/plugins\#pages)

插件可以在 magpie 的窗口里加一个自己的页面。插件打开后，侧边栏的插件分组里会出现它的标签，排在 magpie 自带页面的后面。页面就是插件文件夹里的 HTML、CSS 和 JavaScript，不需要 Bun，也不用构建。下面的例子显示今天的用量。

package.json复制

```
{
  "name": "magpie-usage-glance",
  "version": "0.1.0",
  "magpie": {
    "page": { "title": "Usage glance", "file": "page/index.html", "icon": "page/icon.svg" },
    "permissions": ["usage:summary"]
  }
}
```

page/index.html复制

```
<!doctype html>
<link rel="stylesheet" href="style.css">
<script src="_magpie/bridge.js"></script>   <!-- served beside every page -->
<script src="app.js" defer></script>
<p id="calls">…</p>
```

page/app.js复制

```
await magpie.ready                                  // the window's theme, painted
const s = await magpie.read("usage:summary", { period: "today" })
document.getElementById("calls").textContent = `${s.calls} calls`
const opts = await magpie.options.get()            // this plugin's own options
await magpie.options.set({ ...opts, hideCost: true })
```

插件打开之前，插件页面就会在它的那一行显示这个页面和它能读什么。`page.file` 和 `page.icon` 是插件里面的路径；页面的文件就是 `file` 所在文件夹里的文件，指向外面的路径或链接不会被提供。一个包可以同时是页面、供应商、中间件或 agent。只有页面的插件不会启动插件宿主。

### 页面能请求什么

| 字段 / 调用 | 给出什么 |
| --- | --- |
| `magpie.ready` | 窗口回应后得到窗口的主题。在那之前页面还没和 magpie 说过话；10 秒内没说的页面会显示为没有回应。 |
| `magpie.theme, magpie.onTheme(fn)` | `{ dark, lang, tokens }`。bridge 也会在 `<html>` 上设置 `data-theme`、`lang`、`color-scheme` 以及 `--magpie-bg`、`--magpie-fg`、`--magpie-accent` 等，每次变化都会再设一次。 |
| `magpie.options.get(), .set(o)` | 插件自己在 plugins.json 里的选项，不能是别的插件的。`set` 接受一个对象，返回保存后的选项，每秒最多一次。 |
| `magpie.read(name, params)` | `magpie.permissions` 声明过的读取。其他的一律拒绝，窗口拒绝一次，magpie 再拒绝一次。`usage:summary`（`period`：`today`、`7d` 或 `30d`）给出调用数、错误数、token 和费用，以及前 20 个模型；`providers:list` 给出每个供应商的 id 和名字。没有任何读取会给出密钥、账号、登录信息或请求内容。 |

### 页面不能做什么

- 页面运行在只允许脚本的沙盒框架里（`sandbox="allow-scripts"`，它的 `Content-Security-Policy` 里也一样），有自己独立的 origin。它碰不到窗口、magpie 的 cookie 和窗口的存储。
- 它的策略只允许加载自己的文件：`connect-src 'none'`，所以没有 `fetch`、WebSocket 或 beacon，也没有表单和框架。脚本必须是文件（`<script src>`），不能内联；内联样式和 `data:` 图片可以。
- 这种框架能发出的请求（`Origin: null`、框架请求、别的网站的请求），magpie 的 API 都会拒绝，所以就算没有策略，页面也进不了 API。它的文件从 `/_magpie/plugin/<token>/` 提供，token 每次 magpie 启动都会变。
- 页面仍然可以把自己跳转到别的网站，那个网站就接管了它的框架。所以读取只给不机密的东西：把页面能读到的都当作公开的。
- 页面没接住的错误会在它的位置显示此页面已停止工作和重试。它自己脚本的错误在页面里只显示为“Script error.”，详细内容看窗口的控制台。

## [pi 扩展包](https://usemagpie.ai/docs/zh/plugins\#pi)

magpie 也运行 [pi](https://github.com/earendil-works/pi) 的扩展包。用 `pi.registerProvider` 注册了供应商的 pi 扩展，在 magpie 里和在 pi 里一样工作，不用改任何东西，添加方式和其他插件相同（`magpie plugin add pi-antigravity`）。

- **怎样算 pi 的包。**`package.json` 里有 `pi` 清单（`"pi": { "extensions": [...] }`）、有 `pi-package` 关键词，或者 `dependencies`、`peerDependencies` 里有 `@earendil-works/pi-coding-agent`（或旧的 `@mariozechner/pi-coding-agent`）。单个文件导入了 pi 也算。
- **加载。** magpie 在包旁边装好 pi，用 pi 自己的加载器在同一个插件宿主里加载它。它注册的供应商成为 magpie 的供应商，模型就是 pi 为它们列出的那些（pi 能拉取账号自己的列表时用那份）。它的命令、工具、渲染器和事件处理器都不会用到。
- **登录。** OAuth 登录按 pi 的方式进行：它的提问（`onPrompt`）在 magpie 的登录流程里问，它的页面（`onAuth`）在浏览器里打开，`refreshToken` 负责续期。扩展包用 `ctx.ui` 弹出的对话框（`select`、`confirm`、`input`、`editor`）和交给 `ctx.ui.custom` 的终端组件，也都变成 magpie 的提问。要 API key 的供应商会有一个填 key 的输入框。每次登录就是一个账号，所以 pi 的供应商也能有多个账号。
- **pi 的文件。** pi 的设置、它的 `auth.json`（按 pi 的方式保存每个供应商的第一个账号）以及扩展包自己写的文件，都放在 magpie 配置目录下的 `pi/` 里，不会动用户的 `~/.pi`，除非设置了 `PI_CODING_AGENT_DIR`。账号本身和其他插件一样存在 `plugin-auth.json` 里。
- **请求。** pi 供应商的模型接收 Anthropic Messages：网关把 agent 发来的请求翻译过去，magpie 通过 pi 流式发送，回复里的思考、签名和工具调用都会保留。厂商的错误会带着状态码传回，所以故障切换和其他插件一样有效。
- **id。** pi 供应商的 id 和其他插件规则相同，见 [供应商 id](https://usemagpie.ai/docs/zh/plugins#ids)。

## [宿主协议](https://usemagpie.ai/docs/zh/plugins\#protocol)

写插件用不到这一节，它是给开发 magpie 本身或调试宿主的人看的。magpie 向宿主的 stdin 写入 `{id, method, params}`，每行一条。宿主回复 `{id, result}` 或 `{id, error: {message}}`。

| 方法 | 作用 |
| --- | --- |
| `init` | 加载插件，运行它们的 `config` 钩子。其他调用都会等它完成。 |
| `providers` | 每个供应商、它的登录方式、账号，以及每个账号的模型。 |
| `prompt`、`validate` | 登录方式的下一个提问；校验一个回答。 |
| `authorize`、`callback`、`apiKey` | 登录。 |
| `load` | 某个账号的 loader 选项。 |
| `fetch` | 一个请求。先流式发出 `{id, event: "head", status, headers}`，然后是 `{id, event: "chunk", data}`（base64），最后 `{id, result: null}`。`{method: "abort", params: {id}}` 取消它。 |
| `usage`、`check` | 账号的用量；像真实请求一样检查一个账号。 |
| `import`、`take`、`signOut`、`reload` | 账号的迁入迁出、删除，以及重新运行它们的 loader。 |

宿主也会主动发送事件：`log`、`toast`、`auth`（登录信息已保存或刷新）和 `signIn`（账号的登录状态，同上）。源码见 [`internal/plugin/host.js`](https://github.com/yetone/magpie/blob/main/internal/plugin/host.js)。

## [答疑](https://usemagpie.ai/docs/zh/plugins\#faq)

### 我的 OpenCode 插件不改就能在 magpie 里用吗？

可以，只要它通过 `auth`、`config`、`provider` 和 `chat.headers` 来登录和发请求。magpie 增加的部分（`auth.usage`、`auth.refresh`、`magpie.icon`、`maxConcurrency`、`free`、`rate`、`X-Magpie-Sign-In`）OpenCode 都会忽略，所以一个包能同时服务两边。

### 我的 pi 扩展包能在 magpie 里用吗？

能，只要它通过 `pi.registerProvider` 登录并提供模型。magpie 只使用它注册的供应商，见 [pi 扩展包](https://usemagpie.ai/docs/zh/plugins#pi)。给它加上 `pi-package` 关键词，搜索就能找到它。

### 为什么我的供应商叫 `…-plugin`？

它的 id 在 magpie 里已经有了。见 [供应商 id](https://usemagpie.ai/docs/zh/plugins#ids)。

### 我的一些辅助函数被当成插件运行了。

入口模块导出的每个函数都会被当作插件调用。只导出插件函数，或者用 `export default { id, server }`。

### 可以用 npm 依赖吗？

可以。它们会随插件一起安装，但安装脚本不会运行。Bun 的 `fetch`、`crypto`、`fs` 和 `$` 能满足大部分需要。

### 插件可以调用厂商的 CLI 吗？

可以，用 Bun 的 `$` 或 `child_process`。好几个社区插件就是通过厂商自己的 CLI 登录的。要考虑到有些机器上没装它，在错误信息里说明怎么安装。

### 插件能看到用户的哪些内容？

它发出的请求里的一切：对话、工具及其结果。只把它发到用户要求的地方，也不要记进日志。

### 怎么让 magpie 看到我的修改？

终端里的 `magpie` 命令每次都按文件夹的当前内容加载。在应用里，到插件把它关掉再打开。

有问题，或者有插件想分享？来 [Discord](https://discord.gg/vGSnD3ZKQF) 问，或在 [magpie-community/plugins](https://github.com/magpie-community/plugins) 开 issue。