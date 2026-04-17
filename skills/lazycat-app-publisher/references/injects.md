# Script Injection (injects) 完整参考

`injects` 用于在不修改 OCI image 或应用源码的前提下，按规则注入脚本，覆盖浏览器行为、请求行为和响应行为。

---

## 适用场景

- **密码填充与自动登录** - 见 [passwordless-login.md](passwordless-login.md)
- **CORS/CSP 微调** - 按路径精确增删响应头
- **替换浏览器文件对话框** - 接入 LazyCat 网盘文件选择流程
- **隐藏或修改页面元素** - 不改上游源码做 UI 适配
- **高级路由** - 在 request/response 阶段结合 `ctx.proxy` 做动态反向代理
- **请求头/响应头兼容修正** - 补充鉴权头、修正 WebSocket 头、清理冲突头
- **按用户持久化行为** - 通过 `ctx.persist` 保存用户侧配置
- **请求级诊断与排障** - 用 `ctx.dump` 输出关键请求/响应信息
- **开发态代理** - 前端/后端开发时代理到开发机

---

## 阶段与执行环境

每个 inject 只属于一个阶段：

| Phase | Runtime | Description |
|-------|---------|-------------|
| `on=browser` | 浏览器 | 在应用页面真实浏览器环境执行 |
| `on=request` | lzcinit 沙盒 | 请求转发到 upstream 前执行 |
| `on=response` | lzcinit 沙盒 | 收到 upstream 响应后执行 |

### 执行顺序

1. 按 `application.injects` 的声明顺序
2. 再按同一 inject 的 `do[]` 声明顺序
3. 命中策略是 `all-match-run`，同阶段所有命中 inject 都执行

### 中断行为

- `request/response` 阶段里，`ctx.response.send(...)` 或 `ctx.proxy.to(...)` 生效后立即短路
- 任一脚本报错，当前阶段立即终止并返回错误

### ⚠️ 执行模型约束

- `request/response` 阶段为**同步执行模型**，不支持 `Promise` / `async`
- `browser` 阶段允许异步（例如 `ctx.persist` Promise 调用）

---

## 匹配规则

### 匹配字段

| 字段 | 说明 |
|------|------|
| `when` | 命中条件（OR），任意一条命中即可进入候选 |
| `unless` | 排除条件（OR），任意一条命中即排除 |
| `prefix_domain` | 仅匹配 `<prefix>-` 前缀域名请求 |
| `auth_required` | 默认 `true`。请求没有合法 `SAFE_UID` 时跳过 |

### 规则格式

```
<path-pattern>[?<query>][#<hash-pattern>]
```

### 规则语义

- 仅支持后缀 `*` 作为前缀匹配；无 `*` 时为精确匹配
- `query` token 支持 `key` 或 `key=value`，单条规则内为 AND
- **`#hash` 仅 browser 阶段支持，request/response 阶段不支持 hash 规则**

### 示例

| 规则 | 匹配 | 阶段限制 |
|------|------|---------|
| `"/"` | 仅根路径 | 所有阶段 |
| `"/*"` | 任意路径 | 所有阶段 |
| `"/api/*?v=2"` | `/api/` 前缀 + query 包含 `v=2` | 所有阶段 |
| `"/#login"` | hash 为 `login` | **仅 browser** |

---

## Manifest 示例

```yaml
application:
  injects:
    # browser 阶段：登录页自动填充
    - id: login-autofill
      when:
        - /#login
        - /#signin
      do:
        - src: builtin://simple-inject-password
          params:
            # 简单字段名使用点语法：{{ .U.xxx }}
            # 仅当字段名包含特殊字符（如 "."）时才使用 index 语法
            user: "{{ .U.login_user }}"
            password: "{{ .U.login_password }}"

    # request 阶段：注入 Basic Auth
    - id: inject-basic-auth-header
      auth_required: false
      on: request
      when:
        - /api/*
      do: |
        ctx.headers.set("Authorization", "Basic " + ctx.base64.encode("admin:admin123"));

    # response 阶段：移除 CORS 头
    - id: remove-cors
      on: response
      when:
        - /api/*
      unless:
        - /api/admin/*
      do: |
        ctx.headers.del("Access-Control-Allow-Origin");
        ctx.headers.del("Access-Control-Allow-Credentials");
```

---

## `do` 写法

### Short Syntax

```yaml
do: |
  console.log("Hello from inject");
```

### Long Syntax（多条脚本）

```yaml
do:
  - src: |
      console.log("First action");
  - src: builtin://simple-inject-password
    params:
      username: admin
      password: secret
```

---

## 动态参数 `$persist`

`params` 支持用 `$persist` 动态取值，按当前请求的 `SAFE_UID` 解析：

```yaml
params:
  user:
    $persist: "saved_username"
  password:
    $persist: "saved_password"
    default: ""  # 未命中时返回默认值
```

### 行为说明

| 情况 | 结果 |
|------|------|
| 命中持久值 | 返回持久值 |
| 未命中 + 有 default | 返回 default |
| 未命中 + 无 default | 返回 `null` |

---

## `ctx` 完整 API

### 通用字段（所有阶段）

| 字段 | 类型 | 说明 |
|------|------|------|
| `ctx.id` | `string` | 当前 inject 的 `id` |
| `ctx.src` | `string` | 当前脚本来源 |
| `ctx.phase` | `string` | 当前阶段：`browser`/`request`/`response` |
| `ctx.params` | `object` | 当前脚本参数（已完成 `$persist` 解析） |
| `ctx.safe_uid` | `string` | 当前请求对应的平台用户 ID |
| `ctx.request.host` | `string` | 请求 host |
| `ctx.request.path` | `string` | 请求 path |
| `ctx.request.raw_query` | `string` | 原始 query（不带 `?`） |

### 阶段扩展字段

| 字段 | 阶段 | 类型 | 说明 |
|------|------|------|------|
| `ctx.request.hash` | browser | `string` | URL hash（不带 `#`） |
| `ctx.request.method` | request/response | `string` | 请求方法（大写） |
| `ctx.status` | response | `int` | 当前响应状态码 |
| `ctx.runtime.executedBefore` | browser | `bool` | 页面生命周期内是否执行过 |
| `ctx.runtime.executionCount` | browser | `int` | 页面生命周期内执行次数 |
| `ctx.runtime.trigger` | browser | `string` | 本次触发来源 |

### Helper 可用性矩阵

| Helper | browser | request | response |
|--------|---------|---------|----------|
| `ctx.base64` | ✅ | ✅ | ✅ |
| `ctx.persist` | ✅ (异步) | ✅ | ✅ |
| `ctx.headers` | ❌ | ✅ | ✅ |
| `ctx.body` | ❌ | ✅ | ✅ |
| `ctx.flow` | ❌ | ✅ | ✅ |
| `ctx.fs` | ❌ | ✅ | ✅ |
| `ctx.client` | ❌ | ✅ | ✅ |
| `ctx.dev` | ❌ | ✅ | ✅ |
| `ctx.net` | ❌ | ✅ | ✅ |
| `ctx.dump` | ❌ | ✅ | ✅ |
| `ctx.response` | ❌ | ✅ | ✅ |
| `ctx.proxy` | ❌ | ✅ | ✅ |

---

## Helper 详细 API

### `ctx.base64`

```javascript
ctx.base64.encode(text) -> string
ctx.base64.decode(text) -> string
```

### `ctx.persist` - 跨请求持久化

按 `SAFE_UID` 隔离，用于保存用户侧配置。

**request/response 阶段（同步）：**

```javascript
ctx.persist.get(key) -> any
ctx.persist.set(key, value) -> void
ctx.persist.del(key) -> void
ctx.persist.list(prefix?) -> Array<{key, value}>
```

**browser 阶段（异步）：**

```javascript
await ctx.persist.get(key) -> Promise<any | undefined>
await ctx.persist.set(key, value) -> Promise<void>
await ctx.persist.del(key) -> Promise<void>
await ctx.persist.list(prefix?) -> Promise<Array<{key, value}>>
```

### `ctx.flow` - 请求级临时共享

同一请求内 request -> response 共享状态，请求结束后清空。

```javascript
ctx.flow.get(key) -> any
ctx.flow.set(key, value) -> void
ctx.flow.del(key) -> void
ctx.flow.list(prefix?) -> Array<{key, value}>
```

**典型用法：** request 阶段捕获候选值写入 `flow`，response 阶段成功后写入 `persist`。

### `ctx.headers` - HTTP 头操作

```javascript
ctx.headers.get(name) -> string          // 获取单个值
ctx.headers.getValues(name) -> string[]  // 获取所有值
ctx.headers.getAll() -> Record<string, string[]>
ctx.headers.set(name, value) -> void     // 设置（覆盖）
ctx.headers.add(name, value) -> void     // 添加（不覆盖）
ctx.headers.del(name) -> void            // 删除
```

### `ctx.body` - Body 读写

```javascript
ctx.body.getText(opts?) -> string
ctx.body.getJSON(opts?) -> any
ctx.body.getForm(opts?) -> Record<string, string | string[]>
ctx.body.set(body, opts?) -> void
```

**opts 参数：**

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `max_bytes` | `int` | `1048576` | `get*` 读取最大字节数 |
| `content_type` | `string` | - | `set` 时覆盖 Content-Type |

**⚠️ 注意：** `ctx.body.getJSON()` 直接解析失败时需要捕获异常。

### `ctx.response` - 短路返回

```javascript
ctx.response.send(status, body?, opts?) -> void
```

**opts 参数：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `headers` | `object` | 附加响应头 |
| `content_type` | `string` | 设置 Content-Type |
| `location` | `string` | 重定向地址（301/302 等必须提供） |

**重要：** 调用后必须 `return;` 停止后续执行。

### `ctx.proxy` - 动态反代

```javascript
ctx.proxy.to(url, opts?) -> void
```

**opts 参数：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `use_target_host` | `bool` | 把 Host 改为目标 host |
| `timeout_ms` | `int` | 代理超时 |
| `path` | `string` | 重写 path |
| `query` | `string` | 重写 query（不带 `?`） |
| `via` | `object` | 网络路径对象 |
| `on_fail` | `string` | 失败策略：`keep_original` 或 `error` |

### `ctx.net` - 网络探测

```javascript
ctx.net.joinHost(host, port) -> string
ctx.net.via.host() -> object          // 访问 lzcos host network
ctx.net.via.client(id) -> object      // 访问指定客户端节点
ctx.net.reachable(protocol, host, port, via?) -> bool
```

- `protocol` 支持 `tcp`、`tcp4`、`tcp6`
- `reachable(...)` 为实时探测，默认超时约 `1200ms`

### `ctx.dev` - 开发机状态

```javascript
ctx.dev.id -> string        // 当前开发机 ID
ctx.dev.online() -> bool    // 开发机在线状态（缓存）
```

### `ctx.fs` - 文件系统

```javascript
ctx.fs.exists(path) -> bool
ctx.fs.readText(path, opts?) -> string
ctx.fs.readJSON(path, opts?) -> any
ctx.fs.stat(path) -> object
ctx.fs.list(path) -> string[]
```

### `ctx.dump` - 调试输出

```javascript
ctx.dump.request(opts?) -> string
ctx.dump.response(opts?) -> string
```

**opts 参数：**

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `include_body` | `bool` | `false` | 是否包含 body |
| `max_body_bytes` | `int` | `4096` | body dump 最大字节数 |

---

## 开发态 Inject 模板

### 前端开发代理

把 LPK 入口代理到开发机的 dev server（vite/webpack 等）：

```yaml
application:
  routes:
    - /=file:///lzcapp/pkg/content/dist
#@build if env.DEV_MODE=1
  injects:
    - id: frontend-dev-proxy
      on: request
      auth_required: false
      when:
        - "/*"
      do:
        - src: |
            const devPort = 3000;
            const contentType = "text/html; charset=utf-8";

            function renderDevPage(title, subtitle, steps) {
              const items = steps.map(function (step) {
                return "<li>" + step + "</li>";
              }).join("");
              return [
                "<!doctype html>",
                "<html><head><meta charset=\"UTF-8\"><title>Dev</title></head>",
                "<body><h1>", title, "</h1><p>", subtitle, "</p><ol>", items, "</ol></body></html>",
              ].join("");
            }

            // 1. 检查开发机是否绑定
            if (!ctx.dev.id) {
              ctx.response.send(200, renderDevPage(
                "Dev machine not linked",
                "Waiting for frontend dev server.",
                ["Run lzc-cli project deploy", "Start npm run dev"]
              ), { content_type: contentType });
              return;
            }

            // 2. 检查开发机是否在线
            const via = ctx.net.via.client(ctx.dev.id);
            if (!ctx.dev.online()) {
              ctx.response.send(200, renderDevPage(
                "Dev machine offline",
                "The linked dev machine is not reachable.",
                ["Bring dev machine online", "Start npm run dev"]
              ), { content_type: contentType });
              return;
            }

            // 3. 检查 dev server 是否就绪
            if (!ctx.net.reachable("tcp", "127.0.0.1", devPort, via)) {
              ctx.response.send(200, renderDevPage(
                "Frontend dev server not ready",
                "Waiting for port " + devPort,
                ["Start npm run dev on port " + devPort]
              ), { content_type: contentType });
              return;
            }

            // 4. 代理到开发机
            ctx.proxy.to("http://127.0.0.1:" + devPort, {
              via: via,
              use_target_host: true,
            });
#@build end
```

### 后端开发引导页

服务未 ready 返回静态引导页：

```yaml
application:
#@build if env.DEV_MODE!=1
  routes:
    - /=exec://3000,/app/run.sh
#@build end
#@build if env.DEV_MODE=1
  injects:
    - id: backend-dev-proxy
      on: request
      auth_required: false
      when:
        - "/*"
      do:
        - src: |
            const backendPort = 3000;

            if (!ctx.net.reachable("tcp", "127.0.0.1", backendPort)) {
              ctx.response.send(200, [
                "<!doctype html><html><body>",
                "<h1>Backend not ready</h1>",
                "<ol>",
                "<li>Run lzc-cli project sync --watch</li>",
                "<li>Run lzc-cli project exec /bin/sh</li>",
                "<li>Start backend: /app/run.sh</li>",
                "</ol></body></html>",
              ].join(""), { content_type: "text/html" });
              return;
            }

            ctx.proxy.to("http://127.0.0.1:" + backendPort, {
              use_target_host: true,
            });
#@build end
```

---

## 内置脚本

| Script | Purpose |
|--------|---------|
| `builtin://simple-inject-password` | 密码自动填充（见 [passwordless-login.md](passwordless-login.md)） |
| `builtin://hello` | 测试 inject 执行 |

---

## 调试技巧

### 推荐调试顺序

1. inject 是否在当前路径命中
2. `ctx.dev.id` 是否为空（开发态）
3. `ctx.dev.online()` 是否为 `true`
4. `ctx.net.reachable(...)` 是否为 `true`
5. `ctx.proxy.to(...)` 的 `via` 是否正确

### 添加 Debug Headers

```javascript
ctx.headers.set("X-Debug-Dev-ID", ctx.dev.id || "");
ctx.headers.set("X-Debug-Dev-Online", String(ctx.dev.online()));
ctx.headers.set("X-Debug-Path", ctx.request.path);
```

### 输出请求/响应详情

```javascript
console.log(ctx.dump.request({ include_body: true }));
console.log(ctx.dump.response({ include_body: true }));
```

---

## 常见错误

| 错误 | 原因 | 修复 |
|------|------|------|
| `when` 写了 `#hash` 但 `on=request/response` | hash 规则仅 browser 支持 | 改用路径规则 |
| 没有 `SAFE_UID` 且 `auth_required=true` | inject 被跳过 | 设置 `auth_required: false` |
| `ctx.body.getJSON()` 解析失败 | body 不是合法 JSON | 添加错误处理 |
| 调用 `ctx.response.send()` 后没有 `return` | 继续执行后续代码 | 添加 `return;` |
| 在 `request/response` 使用 `async/await` | 同步执行模型不支持 | 移除异步语法 |

---

## 最佳实践

### 1. 使用 build 预处理裁剪 dev-only inject

```yaml
#@build if env.DEV_MODE=1
  injects:
    - id: dev-proxy
#@build end
```

这样 release 渲染结果里不会带这段 inject。

### 2. request -> response 协作模式

```yaml
# request 阶段：捕获候选值
injects:
  - id: capture
    on: request
    do: |
      ctx.flow.set("pending_user", username);
      ctx.flow.set("pending_pass", password);

# response 阶段：成功后持久化
  - id: commit
    on: response
    do: |
      if (ctx.status >= 200 && ctx.status < 300) {
        ctx.persist.set("saved_user", ctx.flow.get("pending_user"));
        ctx.persist.set("saved_pass", ctx.flow.get("pending_pass"));
      }
```

### 3. 未 ready 时返回明确引导页

不建议默认 fallback 到 release 路由，这会掩盖开发态状态。

---

**参考文档：**

- [passwordless-login.md](passwordless-login.md) - 免密登录完整指南
- [strict-constraints.md](strict-constraints.md) - 配置文件约束
- 官方文档：https://developer.lazycat.cloud

**最后更新**: 2026-04-14