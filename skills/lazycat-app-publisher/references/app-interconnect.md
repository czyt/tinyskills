# 应用间访问 (App Interconnect)

> 要求：`lzcos >= v1.5.2`

本文说明 lzcapp 如何在懒猫微服内以"代表当前真实用户"的语义访问其他 lzcapp 的 HTTP 服务。

## 适用场景

1. 一个应用的前端访问另一个应用的后端。
2. 一个应用访问其他应用暴露的 MCP HTTP 服务。
3. 应用通过统一入口访问自己的 canonical HTTP 面。

## 核心概念

访问目标统一使用 `.lzcx` 地址：

```
http://app.<target-pkg-id>.lzcx/api/tasks
```

例如：

```
http://app.cloud.lazycat.app.todo.lzcx/api/tasks
```

**规则：**
1. `.lzcx` 是 app 级入口，不提供 service 级选择能力。
2. 系统复用 `heiyu.space` 访问所使用的 ingress 路由语义。
3. 多实例应用根据真实用户 `uid` 自动路由到对应实例。
4. 应用访问自身也使用同一套入口：`http://app.<self-pkg-id>.lzcx/...`。

## 权限模型

### `lzcapp.self_delegate`
允许系统向当前应用下发用户票据。

- ✅ 适用于：应用访问自己的 `app.<self-pkg-id>.lzcx`
- ❌ 不适用于：访问其他应用

### `lzcapp.user_delegate`
允许应用代表当前真实用户访问其他应用。

- ✅ 适用于：访问其他应用的 `app.<target-pkg-id>.lzcx`
- ✅ 适用于：访问 `app.home.system.lzcx`

## 最小配置

```yml
# 只访问自己
package: cloud.lazycat.app.demo
permissions:
  required:
    - lzcapp.self_delegate
```

```yml
# 需要访问其他应用
package: cloud.lazycat.app.demo
permissions:
  required:
    - lzcapp.user_delegate
```

## 如何获取 `X-HC-USER-TICKET`

应用没有独立的"主动申请票据"接口。获取方式：

1. 在 `package.yml` 中声明 `lzcapp.self_delegate` 或 `lzcapp.user_delegate`。
2. 真实用户通过正常微服 HTTP 入口访问该应用。
3. 系统在转发用户请求时，在请求 header 中注入 `X-HC-USER-TICKET`。
4. 应用从自己的入站 HTTP 请求 header 中读取该值并保存。

典型流程：

```
1. 用户打开应用页面
2. 应用后端从请求 header 读取 X-HC-USER-TICKET
3. 应用保存到会话/数据库
4. 后续应用用该值访问 app.<target>.lzcx
```

使用示例：

```bash
# 访问其他应用
curl -H "X-HC-USER-TICKET: <ticket>" \
  http://app.cloud.lazycat.app.todo.lzcx/api/tasks

# 访问自身
curl -H "X-HC-USER-TICKET: <ticket>" \
  http://app.cloud.lazycat.app.demo.lzcx/api/profile
```

## 当前限制

1. `X-HC-USER-TICKET` 的获取方式是临时方案，不保证"首次请求一定能拿到"。
2. `lzcapp.self_delegate` 只适用于访问自己；访问其他应用仍需 `lzcapp.user_delegate`。
3. 预计 `lzcos v1.7.x` 改为用户明确授权后才能获取票据。
4. 新应用设计时应预留后续显式授权接入能力。

## 转发后的请求语义

目标应用收到转发请求时，可以信任以下 header：

| Header | 说明 |
|--------|------|
| `X-HC-USER-TICKET` | 代表当前真实用户的认证票据 |
| `X-HC-USER-ID` | 建议使用的用户 ID 标识 |
| `X-HC-USER-NAME` | 用户名 |
| `X-HC-USER-IS-ADMIN` | 是否为管理员 |
