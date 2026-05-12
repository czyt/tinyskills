# Skill / MCP 资源导出

> 要求：`lzcos >= v1.5.2`

本文说明两件事：
1. Agent（小龙猫、Codex 等）如何接入微服里的 Skill / MCP。
2. 应用如何向微服提供自己的 Skill / MCP。

## 给 agent 接入 Skill / MCP

应用要读取微服里的 Skill / MCP，先在 `package.yml` 中声明 `import_resources`：

```yml
# package.yml
import_resources:
  - kind: skills
  - kind: mcp-providers
```

运行时，agent 直接读取：

```
/lzcapp/run/resources/skills/
/lzcapp/run/resources/mcp-providers/
```

微服里的接入起点是系统内置的：

```
/lzcsys/run/pkgm/resources/skills/system/lazycat-local-resource.skill/SKILL.md
```

agent 只需要优先读取这份 `SKILL.md`，它负责告诉 agent：
1. 当前系统有哪些可用 Skill。
2. 当前系统有哪些可用 MCP provider。
3. Skill 到哪里读取。
4. MCP provider 的地址如何拼出来。

接入流程：
1. 加载 `lazycat-local-resource.skill`。
2. 按规则发现可用 Skill，读取 `SKILL.md`。
3. 按规则发现可用 MCP provider，读取 `mcp.yml` 并连接地址。

## MCP 接入

每个 MCP provider 带有 `mcp.yml`，关键字段：

```yml
endpoint: /mcp
```

agent 读取 `endpoint` 后，按 `.lzcx` 规则拼出完整地址：

```
http://app.<应用包名>.lzcx<endpoint>
```

例如：

```yml
endpoint: /mcp?view=default
```

对应：

```
http://app.cloud.lazycat.app.todo.lzcx/mcp?view=default
```

### 鉴权

访问其他应用提供的 MCP 时：
1. 在 `package.yml` 声明 `lzcapp.user_delegate`。
2. 从真实用户请求取得 `X-HC-USER-TICKET`。
3. 带票据访问 `http://app.<包名>.lzcx<endpoint>`。

## 制作提供 Skill / MCP 的 LPK

### 目录结构

```
demo-app/
  package.yml
  lzc-build.yml
  resources/
    skills/
      <resource-id>/
        SKILL.md
    mcp-providers/
      <resource-id>/
        mcp.yml
```

### 配置

```yml
# package.yml — 无需额外配置
package: cloud.lazycat.app.demo
version: 0.0.1
name: Demo App
```

```yml
# lzc-build.yml
resource_exports:
  - kind: skills
    source: ./resources/skills
  - kind: mcp-providers
    source: ./resources/mcp-providers
```

`source` 指向资源类别目录。构建时，`source` 下的每个一级子目录都会作为一个 `resource-id`。

### 提供 Skill

入口文件：`resources/skills/<resource-id>/SKILL.md`

内容应当说明：
1. 这个 Skill 解决什么问题。
2. agent 进入后先做什么。
3. 需要读取哪些文件。
4. 需要连接哪些服务。

最小示例：

```md
---
name: todo-assistant
description: Read the Todo app data files and help the user summarize and organize tasks.
---

1. Read the task data files first.
2. Summarize the current task list.
3. If the user asks to modify data, call the app's MCP server.
```

### 提供 MCP

入口文件：`resources/mcp-providers/<resource-id>/mcp.yml`

最小内容：

```yml
endpoint: /mcp?view=default
```

应用负责在这个 HTTP 入口上提供 MCP 服务。对外地址为：

```
http://app.<包名>.lzcx<endpoint>
```

## 相关文档

1. [应用间访问](./app-interconnect.md)
2. [package.yml 规范](./spec.md#package-规范)
3. [构建配置规范](./spec.md#构建配置规范)
