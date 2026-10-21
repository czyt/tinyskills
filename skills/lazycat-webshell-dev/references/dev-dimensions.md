# 按开发维度索引（总览）

> 这份文档是入口：先确认你在哪个维度开发，再跳到对应 reference。
> 所有结论来自对 `lzclightos-lpk`（lightos-admin）、`lightosctl`（lightos-core 客户端）、
> 运行中实例的实测，不是推测。

---

## 0. 先分清归属：三层

| 层 | 是什么 | 归属 | 你能做什么 |
| --- | --- | --- | --- |
| 平台层 | `lzc-apis.socket` 上的 gRPC：登录/路由/证书、应用安装、文件、硬件、用户 | 懒猫平台，绑定盒子硬件与 app 身份 | 声明权限后**直接用**，不要重写 |
| LightOS 运行时层 | `lightos-core.sock` 上的 HTTP/JSON + yamux | LightOS 应用自己实现 | **可以复刻**，契约见 [lightosctl-core-contract.md](lightosctl-core-contract.md) |
| 你的应用层 | 你的 LPK：provider、UI、调度逻辑 | 你 | 主要工作区 |

**没有第三层**：不存在"平台的 chroot / rootfs 服务"。

---

## 1. 五条开发路径（先选一条）

| 路径 | 你在做什么 | 需要写的 | 读这些 |
| --- | --- | --- | --- |
| **A. WebShell provider** | 给 LightOS 加一个终端入口 | LPK + 后端桥接 + 前端 | §2 §4 §5 §9 |
| **B. 实例内 agent** | 让会话状态留在实例里 | 实例内进程 + 通信协议 | §4 §6 |
| **C. 自研运行时** | 替换 lightos-core | socket server + runc + yamux | §3 §4 §6 §7 §8 |
| **D. 只做界面** | 用 `lightosctl` 当 SDK | 前端 + 后端薄代理 | §2 §3 §5 §9 |
| **E. 定制 rootfs** | 自己的镜像与预装 | Dockerfile + 首启脚本 | §3 §7 |

路径 A 是 skill 的主线；C/D 是可选进阶，见 [self-hosted-runtime.md](self-hosted-runtime.md)。

---

## 2. 维度 A：契约面（四个接口，别混）

```
浏览器 ──HTTPS──► 你的 provider 后端 ──unix socket──► /lzcinit/lightosctl ──► lightos-core
                          │                                                  （实例管理 / exec / forward）
                          └──HTTPS(credentials:include)──► lightos-admin
                                                             /unsafe_api/webshell/*
                                                             /unsafe_api/publish/*
你的 LPK 容器 ──mTLS gRPC──► /lzcapp/run/sys/lzc-apis.socket（平台：文件/硬件/用户/应用）
```

| 接口面 | 谁提供 | 谁调用 | 稳定性 |
| --- | --- | --- | --- |
| `lightosctl` CLI | LightOS | 你的 provider、你的 agent | **稳定**（首选） |
| lightos-core `/api/*` | LightOS | `lightosctl`、自研客户端 | 稳定但需要 socket + 两个 header |
| lightos-admin `/unsafe_api/*` | lightos-admin | 浏览器（同源带 cookie） | 公开契约 |
| 平台 gRPC | 懒猫平台 | 任何 LPK | 稳定，需声明权限 |

规则：**provider 永远不要直接连 lightos-core socket**（那需要宿主机 socket，第三方 LPK 拿不到）。
`/api/*` 只在"自研运行时"或"调试"时用。

细节：[provider-contract.md](provider-contract.md)、[lightosctl-core-contract.md](lightosctl-core-contract.md)

---

## 3. 维度 B：实例生命周期

```
准备 rootfs → create（写目录+清单）→ start（runc）→ 首启初始化 → 开机自启 → SSH → 停止 → 删除
```

| 环节 | 关键点 | 见 |
| --- | --- | --- |
| rootfs | `docker build` + `docker export`，必须含 `/sbin/init` | [instance-lifecycle.md §1](instance-lifecycle.md) |
| create | 目录布局 + `instances.json`（原子写） | §2 |
| start | OCI bundle → `runc create/start`，runc 自己做 `pivot_root` | §3 |
| 首启 | `/etc/lightos/seed.env` + `lightos-setup.service`（幂等） | §4 |
| 自启 | **runtime 启动时重放 `status==running`**，不是实例内 `systemctl enable` | §5 |
| 用户/密码 | `useradd`/`usermod -l`（Ubuntu 的 uid 1000）+ `chpasswd -c SHA512` | §6 |
| 预装 | `LIGHTOS_PKG_*` 开关 → apt/pacman/npm | §7 |
| SSH | 实例内 sshd 与宿主转发是**两个独立开关** | §8 |
| 停止/删除 | SIGTERM → `runc delete`；删除前必须 stopped | §9 |

**必须记住的三条**：
1. 没有任何一步是宿主 `chroot()`；`pivot_root` 由 runc 完成。
2. 首启只做一次（`/var/lib/lightos/initialized` 守卫），`seed.env` 用完即删。
3. 重启后实例不会自己回来，是你的 core 去重放。

---

## 4. 维度 C：数据面（终端与转发）

| 能力 | 传输 | 要点 |
| --- | --- | --- |
| `exec` | `POST /api/instances/{n}/exec-stream`，body 是 **yamux v1** | 命名流 `control` / `exec-stdin` / `exec-stdout` / `exec-stderr` / `exec-pty` |
| PTY resize | `POST /api/exec-stream/{session_id}/pty-control` | `{"action":"resize","cols":N,"rows":M}`，路径用 session uuid |
| `tcp` | `POST /api/instances/{n}/tcp-stream` | 双向字节流 |
| `forward -R` | `tcp-reverse-listeners` + `accept-stream` **两段式** | 服务端监听，客户端 accept |
| `forward -L` / `-D` | **无服务端端点** | 纯客户端本地实现 |

三条会踩的坑：
- exec 的响应不是 chunked JSON，是 yamux 帧；流名在 SYN 帧 payload 里。
- **exit code 不随流传递**，只能靠约定（`__LIGHTOS_RESULT__:` 之类的标记行）。
- 进入实例的方式是宿主机 `nsenter`，不是实例内的 `lightosctl`（实例里根本没有）。

细节：[self-hosted-runtime.md §4](self-hosted-runtime.md)、[lightosctl-core-contract.md §4 §7](lightosctl-core-contract.md)

---

## 5. 维度 D：身份与访问（四种"用户"，别混）

| 身份 | 存在哪 | 用来做什么 | 生命周期 |
| --- | --- | --- | --- |
| 懒猫账号 | 平台 | 登录、授权、成员 | 平台管理 |
| `owner_deploy_id` | 实例元数据 | 判断实例归属哪个应用 | 随应用部署 |
| 实例内 Linux 用户 | 实例 `/etc/passwd` | `exec` 与 SSH 登录身份 | `create --username` 决定，首启创建 |
| SSH 独立密码 | 运行期状态 | SSH 密码登录 | 运行期可改，与系统密码独立 |

**selector 是安全边界**：`<name>@<owner_deploy_id>`，前端不得自行拼接或改写，
后端每次 list/attach/forward/publish 都要重新校验它属于当前账号。

---

## 6. 维度 E：状态归属（哪些状态必须放在哪）

| 状态 | 权威位置 | 丢失后果 |
| --- | --- | --- |
| 实例清单 | runtime（`instances.json`） | 实例"消失"，rootfs 还在 |
| 实例内配置 | 实例 rootfs（`/etc/lightos/*.env`） | 用户/SSH 配置丢失 |
| 终端 tab/pane | **实例内 agent** 或实例内进程 | 刷新后会话全丢 |
| 终端字节历史 | 单 pane 一份（实例内） | 多端输出分叉 |
| provider 会话缓存 | provider 内存 | 可重建，允许丢 |
| 前端 UI 偏好 | localStorage | 可重建 |
| SSH 密码 | 运行期状态（内存 + 实例 passwd） | 需重设 |

原则：**能重建的不要持久化，不能重建的必须放在它的归属层。**

---

## 7. 维度 F：镜像与发行版

| 项 | 结论 |
| --- | --- |
| 判断发行版 | 优先 `command -v apt-get` / `pacman`，需要名字时才读 `/etc/os-release` |
| Ubuntu 特例 | 自带 uid 1000 的 `ubuntu` 用户，要 `usermod -l` 改名而不是 `useradd` |
| Arch 特例 | 先重建 `/etc/pacman.d/gnupg`，否则签名校验失败 |
| 已验证镜像 | `library/archlinux:latest`、`library/debian:bookworm\|stable\|testing`、`library/ubuntu:26.04`、`omarchy:4.0.4` |
| 镜像源 | Arch→USTC（含 archlinuxcn），Ubuntu/Debian→TUNA，Go→goproxy.cn |

细节：[distro-adaptation.md](distro-adaptation.md)

---

## 8. 维度 G：网络

| 模式 | 特征 | 自研要点 |
| --- | --- | --- |
| `nat` | 默认，独立 IP + 网关 + DNS | 建 veth/bridge，写 `resolv.conf` |
| `host` | 共享宿主网络栈 | **SSH 端口必须显式指定**，否则冲突 |
| `macvlan` | 独立 MAC，仅支持有线网卡 | 需要物理网段 |
| `ipvlan` | 独立 IP，共享 MAC | 同上 |

跨模式规则：从 nat/host 切到 macvlan/ipvlan 需要静态 IP 参数；
host 模式下 `ssh_port` 必填；端口冲突检查在 admin 层（`/api/check-port`）。

---

## 9. 维度 H：前端与 UX

| 维度 | 要求 |
| --- | --- |
| 传输 | WebSocket 默认；gRPC-stream 需代理；SSE 只适合单向 |
| 字节路径 | 终端输入/输出是纯字节，UI 动作不写进 PTY |
| 回放 | `history-replay-start` / `history-replay-complete` 带 selector+pane，不匹配就断开 |
| 输入锁 | 回放完成前、revision 变更时锁输入 |
| 移动端 | safe-area、visual viewport、IME 组合态、触屏快捷键、无 hover 依赖 |
| 返回 | 用 `admin-info --json` 解析 base_url，同页 `location.assign()`，禁止 `window.open` |

细节：[provider-contract.md](provider-contract.md)

---

## 10. 维度 I：打包与发布

| 文件 | 必须包含 |
| --- | --- |
| `package.yml` | `permissions.required: [lightos.manage]`；provider-only 时 `hidden_from_launcher: true` |
| `lzc-build.yml` | `resource_exports: [{kind: lightos.webshell, source: ./resources/lightos.webshell}]` |
| `resources/lightos.webshell/default/webshell-provider.json` | `{"support_home": false, "root_path": "/..."}` |
| `lzc-manifest.yml` | `application.multi_instance: true`（需要按部署隔离状态时） |
| 路由 | 必须与 `root_path` 同前缀 |

验收：`lzc-cli project lint <dir>` 无 warning。

---

## 11. 维度 J：可观测与排障

**标记行协议**（脚本给上层解析用，不要解析人类可读日志）：

```
__LIGHTOS_RESULT__:<text>           构建/命令结果
__LIGHTOS_SYSTEMCTL_EXIT__:<code>   systemctl 返回码
__LIGHTOS_SSH_STATUS__:ready|pending|missing|error
__LIGHTOS_SSH_DETECTED_PORT__:<n>
__LIGHTOS_LPK_SSH_EXIT__:<code>
```

**探活判据**：不要用 `systemctl is-active`，用真实探测（SSH 用 `ssh-keyscan`，HTTP 用请求）。

**状态机**：`inspect` 是唯一进度来源（`init_status` + `init_progress` 0→100），没有事件流，
前端靠轮询。

---

## 12. 维度 K：安全边界

| 边界 | 规则 |
| --- | --- |
| 账号隔离 | selector 每次请求都重新校验，不信任前端 |
| 明文密码 | `seed.env` 首启后必删；SSH 密码不落浏览器存储 |
| 实例逃逸 | `sandbox`=sysbox-runc（user ns），`system`=runc；不要假设 sandbox 有宿主能力 |
| 权限 | `lightos.manage` 是显式扩展点，不是"绕过平台" |
| 端口 | 1024–65535，冲突由 admin 统一裁决 |
| 输出 | 不要把 token、证书、密码写进日志或提交物 |

---

## 13. 交叉矩阵：角色 × 维度

| 维度 | A provider | B agent | C 运行时 | D 只做界面 | E rootfs |
| --- | --- | --- | --- | --- | --- |
| 契约面 | ✅ 必读 | ✅ | ✅ 必读 | ✅ | — |
| 生命周期 | 只读 | — | ✅ 必写 | — | ✅ 部分 |
| 数据面 | ✅ 必写 | ✅ | ✅ 必写 | — | — |
| 身份 | ✅ 必写 | ✅ | ✅ | ✅ | ✅ 首启 |
| 状态归属 | ✅ | ✅ 核心 | ✅ | ✅ | — |
| 镜像/发行版 | 只读 | — | ✅ | — | ✅ 核心 |
| 网络 | — | — | ✅ | 只读 | — |
| 前端 UX | ✅ 核心 | — | — | ✅ 核心 | — |
| 打包发布 | ✅ 核心 | ✅ | ✅ | ✅ | ✅ |
| 可观测 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 安全 | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 14. 文档地图

| 文档 | 内容 |
| --- | --- |
| [provider-contract.md](provider-contract.md) | provider 的稳定契约、必需文件、会话模型、移动端、Catlink/Publish |
| [lightosctl-core-contract.md](lightosctl-core-contract.md) | 17 个 `/api/*` 端点、create 字段、yamux 流名、错误矩阵 |
| [self-hosted-runtime.md](self-hosted-runtime.md) | 自研运行时的完整实现规格（含工作量表） |
| [instance-lifecycle.md](instance-lifecycle.md) | 生命周期全流程：rootfs/首启/自启/用户/预装/SSH/停止 |
| [distro-adaptation.md](distro-adaptation.md) | 发行版差异、已验证镜像、镜像源 |
| [instance-runtime-injection.md](instance-runtime-injection.md) | 平台到底往实例里放了什么（答案：没有） |
| [examples.md](examples.md) | 可运行示例与离线部署 |
