# 免密登录配置指南

LazyCat 应用如果自带密码体系，都需要进行免密配置。本文档详细介绍免密登录的各种实现方式。

---

## 常见免密登录方式

LazyCat 微服中常见的"免密/弱感知登录"方式：

1. **基于 ingress 注入的用户身份 header** - 直接使用 HTTP Headers 做用户管理
2. **OIDC 标准登录流** - 基于 OpenID Connect 打通应用账号体系
3. **部署参数注入固定凭据** - 通过 `lzc-deploy-params.yml` 或部署时环境变量注入
4. **Basic Auth Header 自动注入** - 在网关层注入 Authorization header
5. **Script Injection (injects)** - 通过脚本注入实现免密登录（本文重点）

---

## 方式一：自动注入 Basic Auth Header

**适用场景：**
- 上游服务使用 Basic Auth
- 不想修改上游服务配置

```yaml
application:
  injects:
    - id: inject-basic-auth-header
      on: request
      auth_required: false
      when:
        - /api/*
      do: |
        ctx.headers.set("Authorization", "Basic " + ctx.base64.encode("admin:admin123"));
```

---

## 方式二：部署参数 + simple-inject-password

**适用场景：**
- 登录账号基本固定，或由部署参数提供
- 只需要自动填充，不需要学习用户后续改密结果

### 步骤 1: 定义部署参数

```yaml
# lzc-deploy-params.yml
params:
  # 固定默认用户名，减少部署后首次登录心智负担
  - id: login_user
    type: string
    name: "Login User"
    description: "Default login username"
    default_value: "admin"
    optional: true

  # 密码默认随机生成，避免弱口令
  - id: login_password
    type: secret
    name: "Login Password"
    description: "Default login password"
    default_value: "$random(len=20)"
    optional: true
```

### 步骤 2: 配置 browser inject

```yaml
# lzc-manifest.yml
application:
  injects:
    # browser 阶段：仅在登录相关 hash 路由执行
    - id: login-autofill
      when:
        - /#login
        - /#signin
        - /login
        - /signin
      do:
        - src: builtin://simple-inject-password
          params:
            # 从部署参数渲染得到固定用户名
            user: "{{ index .U \"login_user\" }}"
            # 从部署参数渲染得到随机初始密码
            password: "{{ index .U \"login_password\" }}"
```

### 验证

1. 安装应用时填写部署参数（不填写时使用默认值）
2. 打开登录页（命中 `when` 规则）
3. 账号和密码输入框被自动填充

---

## 方式三：三阶段联动（高级）

**适用场景：**
- 应用首次使用由用户自己创建管理员账号和密码
- 后续用户可能在应用内修改密码
- 希望 inject 自动跟随最新的密码

### 核心思路

1. **request 阶段**：观察创建/登录/改密请求，把候选用户名和密码写入 `ctx.flow`
2. **response 阶段**：仅在响应成功时，把 `ctx.flow` 里的值提交到 `ctx.persist`
3. **browser 阶段**：登录页从 `ctx.persist` 读取并自动填充；改密页自动填充"当前密码"

### 完整示例（Jellyfin）

```yaml
# lzc-manifest.yml
application:
  subdomain: jellyfin
  public_path:
    - /
  routes:
    - /=http://jellyfin:8096
  gpu_accel: true
  injects:
    # request 阶段：抓取首次初始化、登录、改密请求里的候选用户名/密码
    - id: jellyfin-capture-password
      auth_required: false
      on: request
      when:
        - /Startup/User
        - /Users/*
      do: |
        const path = String(ctx.request.path || "");
        const method = String(ctx.request.method || "").toUpperCase();

        const isSetup = path === "/Startup/User" && method === "POST";
        const isUserAuth = /^\/Users\/AuthenticateByName$/i.test(path) && method === "POST";
        const isPasswordUpdate = /^\/Users\/[^/]+\/(Password|EasyPassword)$/i.test(path) && (method === "POST" || method === "PUT");
        if (!isSetup && !isUserAuth && !isPasswordUpdate) return;

        let payload = null;
        try {
          payload = ctx.body.getJSON();
        } catch {
          payload = null;
        }
        if (!payload || typeof payload !== "object") return;

        const pickString = (...values) => values.find((v) => typeof v === "string" && v.length > 0) ?? "";
        const username = pickString(payload.Name, payload.Username, payload.UserName, payload.userName);
        const password = pickString(
          payload.NewPw,
          payload.NewPassword,
          payload.newPw,
          payload.newPassword,
          payload.Password,
          payload.password,
          payload.Pw,
          payload.pw,
        );

        if (username) ctx.flow.set("jf_pending_username", username);
        if (password) ctx.flow.set("jf_pending_password", password);

    # response 阶段：仅在请求成功时提交到持久化存储
    - id: jellyfin-commit-password
      auth_required: false
      on: response
      when:
        - /Startup/User
        - /Users/*
      do: |
        if (ctx.status < 200 || ctx.status >= 300) return;

        const username = ctx.flow.get("jf_pending_username");
        const password = ctx.flow.get("jf_pending_password");
        if (typeof username === "string" && username.length > 0) {
          ctx.persist.set("jellyfin.username", username);
        }
        if (typeof password === "string" && password.length > 0) {
          ctx.persist.set("jellyfin.password", password);
        }

    # browser 阶段：登录页自动填充用户名和密码
    - id: jellyfin-login-autofill
      when:
        - /web/*#/login.html*
        - /web/*#/startup/login*
      do:
        - src: builtin://simple-inject-password
          params:
            user:
              $persist: jellyfin.username
            password:
              $persist: jellyfin.password
            userSelector: "#txtManualName"
            passwordSelector: "#txtManualPassword"

    # browser 阶段：改密页自动填充"当前密码"，但不自动提交
    - id: jellyfin-userprofile-current-password
      when:
        - /web/*#/userprofile.html*
      do:
        - src: builtin://simple-inject-password
          params:
            password:
              $persist: jellyfin.password
            passwordSelector: "#txtCurrentPassword"
            autoSubmit: false

services:
  jellyfin:
    image: registry.lazycat.cloud/nyanmisaka/jellyfin:250503-amd64
    binds:
      - /lzcapp/var/config:/config
      - /lzcapp/var/cache:/cache
      - /lzcapp/run/mnt/media:/media/
```

### 验证

1. 首次初始化管理员账号后，退出并回到登录页，验证自动填充生效
2. 进入用户资料页修改密码，验证"当前密码"输入框自动填充旧密码
3. 改密成功后退出登录，验证下次登录页自动填充为新密码

---

## builtin://simple-inject-password 参数说明

| 参数 | 类型 | 说明 | 默认值 |
|------|------|------|--------|
| `user` | `string` | 账号值 | 空 |
| `password` | `string` | 密码值 | 空 |
| `requireUser` | `bool` | 是否必须找到账号输入框 | 根据其他参数推断 |
| `allowPasswordOnly` | `bool` | 允许仅填充密码 | `false` |
| `autoSubmit` | `bool` | 是否自动提交 | `true` |
| `submitMode` | `string` | 提交模式：`auto`/`requestSubmit`/`click`/`enter` | `auto` |
| `submitDelayMs` | `int` | 自动提交前延迟（毫秒） | `50` |
| `retryCount` | `int` | 自动提交重试次数 | `10` |
| `retryIntervalMs` | `int` | 重试间隔（毫秒） | `300` |
| `observerTimeoutMs` | `int` | DOM 观察超时（毫秒） | `8000` |
| `debug` | `bool` | 开启调试日志 | `false` |
| `userSelector` | `string` | 显式指定账号输入框选择器 | - |
| `passwordSelector` | `string` | 显式指定密码输入框选择器 | - |
| `formSelector` | `string` | 限定在指定容器内搜索 | - |
| `submitSelector` | `string` | 显式指定提交按钮选择器 | - |
| `allowHidden` | `bool` | 允许填充不可见输入框 | `false` |
| `allowReadOnly` | `bool` | 允许填充只读输入框 | `false` |
| `onlyFillEmpty` | `bool` | 仅当输入框为空时填充 | `false` |
| `allowNewPassword` | `bool` | 允许填充 `autocomplete=new-password` | `false` |
| `includeShadowDom` | `bool` | 搜索 Shadow DOM | `false` |
| `shadowDomMaxDepth` | `int` | Shadow DOM 最大递归深度 | `2` |
| `preferSameForm` | `bool` | 优先选择同表单内的账号框 | `true` |
| `eventSequence` | `string` 或 `[]string` | 触发事件序列 | `input,change,keydown,keyup,blur` |
| `keyValue` | `string` | 键盘事件按键值 | `a` |
| `userKeywords` | `string` 或 `[]string` | 追加账号字段关键词 | - |
| `userExcludeKeywords` | `string` 或 `[]string` | 追加账号字段排除关键词 | - |
| `passwordKeywords` | `string` 或 `[]string` | 追加密码字段关键词 | - |
| `passwordExcludeKeywords` | `string` 或 `[]string` | 追加密码字段排除关键词 | - |
| `submitKeywords` | `string` 或 `[]string` | 追加提交按钮关键词 | - |

---

## 常见错误

### ❌ 错误 1：在 request/response 使用 hash 规则

```yaml
# ❌ 错误：on=request 时写了 hash 规则
injects:
  - id: login
    on: request  # request 阶段没有 hash
    when:
      - /#login  # ❌ hash 规则在 request 阶段不生效
```

**正确做法：**

- `on: request` / `on: response` - 使用路径规则（如 `/api/login`）
- `on: browser` - 可以使用 hash 规则（如 `/#login`）

### ❌ 错误 2：request 阶段直接写入 persist

```yaml
# ❌ 错误：直接在 request 阶段写入 persist
injects:
  - id: capture
    on: request
    do: |
      ctx.persist.set("password", password);  # ❌ 未验证响应是否成功
```

**正确做法：**

```yaml
# ✅ 正确：request 存入 flow，response 成功后存入 persist
injects:
  - id: capture
    on: request
    do: |
      ctx.flow.set("pending_password", password);  # 临时存储

  - id: commit
    on: response
    do: |
      if (ctx.status >= 200 && ctx.status < 300) {
        ctx.persist.set("password", ctx.flow.get("pending_password"));  # 成功后持久化
      }
```

### ❌ 错误 3：未指定选择器导致部分填充

```yaml
# ❌ 错误：页面字段命名特殊，未指定选择器
injects:
  - id: autofill
    when:
      - /login
    do:
      - src: builtin://simple-inject-password
        params:
          user: "admin"
          password: "secret"
          # 未指定 userSelector/passwordSelector，可能只填充部分输入框
```

**正确做法：**

```yaml
# ✅ 正确：显式指定选择器
injects:
  - id: autofill
    when:
      - /login
    do:
      - src: builtin://simple-inject-password
        params:
          user: "admin"
          password: "secret"
          userSelector: "#username-input"
          passwordSelector: "#password-field"
```

---

## 典型应用的免密配置模板

### WordPress / PHP 应用

```yaml
application:
  injects:
    - id: wp-login-autofill
      when:
        - /wp-login.php
        - /wp-admin
      do:
        - src: builtin://simple-inject-password
          params:
            user: "{{ index .U \"admin_user\" }}"
            password: "{{ index .U \"admin_password\" }}"
            userSelector: "#user_login"
            passwordSelector: "#user_pass"
```

### Nginx Proxy Manager / Portainer

```yaml
application:
  injects:
    - id: npm-login
      when:
        - /login
      do:
        - src: builtin://simple-inject-password
          params:
            user:
              $persist: npm.username
            password:
              $persist: npm.password
            userSelector: "input[name='username']"
            passwordSelector: "input[name='password']"
```

### Home Assistant

```yaml
application:
  injects:
    - id: ha-onboarding
      on: request
      when:
        - /api/onboarding/users
      do: |
        const payload = ctx.body.getJSON();
        if (payload && payload.username) {
          ctx.flow.set("ha_username", payload.username);
        }
        if (payload && payload.password) {
          ctx.flow.set("ha_password", payload.password);
        }

    - id: ha-commit
      on: response
      when:
        - /api/onboarding/users
      do: |
        if (ctx.status === 201) {
          ctx.persist.set("homeassistant.username", ctx.flow.get("ha_username"));
          ctx.persist.set("homeassistant.password", ctx.flow.get("ha_password"));
        }

    - id: ha-login-autofill
      when:
        - /
      do:
        - src: builtin://simple-inject-password
          params:
            user:
              $persist: homeassistant.username
            password:
              $persist: homeassistant.password
```

---

## 最佳实践

### 1. 首次部署场景

对于需要首次设置密码的应用：

- 使用三阶段联动方案
- request 阶段捕获初始化请求
- response 阶段验证成功后持久化
- browser 阶段自动填充

### 2. 固定密码场景

对于有默认管理员账号的应用：

- 通过 `lzc-deploy-params.yml` 提供用户名和密码参数
- 使用 `default_value: "$random(len=20)"` 生成随机密码
- browser 阶段使用 `simple-inject-password` 自动填充

### 3. 自定义登录页

对于非标准登录页面：

- 显式指定 `userSelector` 和 `passwordSelector`
- 设置 `autoSubmit: false` 防止过早提交
- 增加 `retryCount` 和 `retryIntervalMs` 处理慢加载页面

---

**最后更新**: 2026-04-14
**基于**: 懒猫开发者文档 advanced-inject-passwordless-login.md