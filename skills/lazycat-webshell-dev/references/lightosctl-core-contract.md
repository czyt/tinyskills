# lightosctl / lightos-core 实测契约（v1.6.2 · 2026-10-21）

本文只记录**实测**（抓包 + 反汇编 `lzcinit`）。所有路径、字段、响应体都有原始字节为证。
用途：写 WebShell provider 时判断"哪些能依赖"，或自研 LightOS 内核时作为唯一规格。

---

## 0. 两层能力，先分清

**先分清"平台"和"应用"是两回事**：LPK 是平台上的应用，可以不依赖 LightOS。
只有需要"持久 Linux 实例"时，才在下面两层中选择。

| 你想做的 | 依赖 LightOS 应用 | 依赖平台 gRPC | 需要宿主机特权 |
| --- | --- | --- | --- |
| 普通 LPK（Web 服务/工具/数据库） | ❌ | 可选 | ❌ |
| 自研实例运行时（LightOS 替代品） | ❌ | 可选 | ✅ runc/sysbox |
| 使用现成实例（WebShell provider） | ✅ | 需要 `lightos.manage` | ❌ |

LightOS 横跨两个完全不同的能力层，自研边界就在这里：

| 层 | 传输 | 归属 | 能否自研 | 具体内容 |
| --- | --- | --- | --- | --- |
| 平台 API | gRPC over `unix:///lzcapp/run/sys/lzc-apis.socket`，mTLS（`app.crt`/`app.key`/`box.crt`） | 懒猫平台，绑定盒子硬件与 app 身份 | ❌ 白拿 | 登录/路由/证书、应用安装、文件、硬件、用户 |
| LightOS 运行时 | HTTP/JSON + yamux over `unix:///lzcapp/run/sys/lightos-core.sock` | LightOS 应用自己实现 | ✅ 可复刻（本文是它的规格） | 实例生命周期、exec/PTY、tcp/forward、网络、统计 |

**没有第三层**：不存在"平台的 chroot / rootfs 服务"。LightOS 的 rootfs 由 `docker build + export` 产生，
发行版差异是在实例内部用 `command -v apt-get/pacman` 判断的，详见 [distro-adaptation.md](distro-adaptation.md)。

平台 API 覆盖：`BoxService`（硬件/关机/时区）、`PackageManager`（装/卸/查应用）、`FileHandler`（文件）、
`PeripheralDeviceService`（磁盘/文稿挂载）、`TvOS`（云桌面）、`localdevice.RemoteControl`。
这些是**公开给所有 LPK 的能力**，按 `package.yml` 声明权限即可用，不属于 LightOS 私有。

`lightos.*` 权限（`lightos.use` = 只管自己的实例；`lightos.manage` = 可管全局并创建超级权限实例）同样是平台授予的，
所以自研 LightOS **不是绕过平台**，而是替换跑在平台上的这一层应用。

---

## 1. 传输与身份

```
unix:///lzcapp/run/sys/lightos-core.sock     可用 LIGHTOS_CORE_SOCKET 覆盖
HTTP/1.1   Host: lightos-core
```

每个请求都带：

```
X-LightOS-Internal-Deploy-ID:    <caller deploy id>
X-LightOS-Internal-Service-Name: <caller service>
```

`lightosctl` 从 `LAZYCAT_APP_DEPLOY_ID`、`LAZYCAT_APP_SERVICE_NAME` 取值。
成功 `200` + JSON；失败 `4xx/5xx` + `{"error":"..."}`，CLI 退出码 1。

---

## 2. 全部端点（14 行，17 个路径）

| CLI | Method | Path | Body |
| --- | --- | --- | --- |
| `ps` | GET | `/api/list` | – |
| `inspect <n>` | GET | `/api/instances/{n}` | – |
| `create` | POST | `/api/create` | §3 |
| `start` / `stop` | POST | `/api/start` `/api/stop` | `{"name":"n"}` |
| `rm` | POST | `/api/delete` | `{"name":"n"}` |
| `capabilities` | GET | `/api/capabilities` | – |
| `security-levels` | GET | `/api/security-levels` | – |
| `system admin-info` | GET | `/api/system/admin-info` | – |
| `build` | POST | `/api/rootfs/dockerfile/build-stream` | §6 |
| `exec` | POST | `/api/instances/{n}/exec-stream` | §4 |
| `exec -t` resize | POST | `/api/exec-stream/{session_id}/pty-control` | §4.3 |
| `tcp` | POST | `/api/instances/{n}/tcp-stream` | §7.1 |
| `forward -R` | POST | `/api/instances/{n}/tcp-reverse-listeners` + `/api/tcp-reverse-listeners/{sid}/accept-stream` | §7.2 |
| `vt status` / `activate` | POST | `/api/vt/status` `/api/vt/activate` | `{"name":"n"}` |

`forward -L` 与 `-D` **没有服务端端点**（纯客户端）。`fuse` 不是子命令；`/api/fuse/mount|unmount` 只给 LPK 挂 document/clientfs。

---

## 3. `POST /api/create`

```json
{
  "name": "g1",
  "rootfs_dest_dir": "/path/rootfs",
  "rootfs_source_dirs": ["/lower1", "/lower2"],
  "security_level": "sandbox",
  "network_mode": "nat",
  "username": "root",
  "mount_dev": false,
  "allow_disk_device": false,
  "vt": false,
  "bind_mounts": [
    {"source_path":"/host","target_path":"/guest","read_only":true,"owner":"1000:1000"}
  ]
}
```

| 字段 | 规则 |
| --- | --- |
| `name` | `^[a-z0-9-]+$`，否则 `name must be lowercase letters, numbers, or hyphen` |
| `rootfs_dest_dir` | 必须已存在且含 `/sbin/init` |
| `rootfs_source_dirs` | 只读 lower dir（overlay），可多个 |
| `security_level` | `sandbox`=sysbox-runc / `system`=runc；默认 `system` |
| `network_mode` | `nat` / `host` / `macvlan` / `ipvlan`；默认 `nat` |
| `username` | 实例内登录用户 |
| `mount_dev` / `allow_disk_device` / `vt` | 布尔；**不传就整个省略**（不是 false） |
| `bind_mounts[]` | `source_path` / `target_path` 必填；`read_only`；`owner:"uid:gid"` |

响应 `{"ok":true,"message":"created"}`。同名再 create → `400 {"error":"bundle already exists"}`（**不覆盖**）。

---

## 4. exec 流

### 4.1 请求

```json
{"session_id":"<uuid4>","command":"/bin/sh","args":["-lc","echo hi"]}
{"session_id":"<uuid4>","command":"/bin/sh","tty":true,"cols":100,"rows":30}
```

实例不存在 → `404 {"error":"instance not found"}`。

### 4.2 响应：yamux(v1) over octet-stream

```
HTTP/1.1 200 OK
Content-Type: application/octet-stream
Cache-Control: no-cache
Connection: close
```

帧：`ver(1)=0 type(1) flags(2) windowID(4) length(4) payload`
`type` 0=DATA 1=WINDOW_UPDATE 2=PING 3=GO_AWAY；`flags` 1=SYN 2=ACK 4=FIN 8=RST。

**命名流 = SYN 帧，payload 是 `"<name>\n"`。**

非 PTY：

```
SYN s=1 "control\n"  SYN s=3 "exec-stdin\n"  SYN s=5 "exec-stdout\n"  SYN s=7 "exec-stderr\n"
DATA s=5 "OUT\n"     DATA s=7 "ERR\n"        FIN s=5 / FIN s=7
```

PTY：

```
SYN s=1 "control\n"  SYN s=3 "exec-pty\n"    DATA s=3 "echo hi\r"
DATA s=3 "/ # \x1b[6n"  ...  FIN s=3
```

- stdin 写入 = 往 `exec-stdin`（或 `exec-pty`）发 DATA
- 输出是**原始字节**，含 ANSI；客户端原样喂终端库
- **退出码不在流里**（`exit 3` 时 CLI 仍返回 0）

### 4.3 resize

```
POST /api/exec-stream/{session_id}/pty-control
{"action":"resize","cols":107,"rows":33}
→ {"ok":true,"message":"resized"}
```

路径里是 **session_id**（exec 请求里的 uuid），不是实例名。

### 4.4 流名总表

| 流名 | 用途 |
| --- | --- |
| `control` | 每个会话都有，流 1 |
| `exec-stdin` / `exec-stdout` / `exec-stderr` | 非 PTY 三路 |
| `exec-pty` | PTY 双向 |
| `tcp-upstream` / `tcp-downstream` | tcp / forward -R |
| `/accept-stream` | 反向监听接受的连接 |

---

## 4.5 真实实例的 bind_mounts（线上样本）

线上 xcoder（`security_level=system`、`network_mode=host`、`vt=true`）的 `/api/list` 输出里，
`bind_mounts` 不是用户手填的，而是 lightos-admin 创建时写入的固定挂载：

| source_path | target_path | 说明 |
| --- | --- | --- |
| `/lzcapp/run/catlink` | `/run/catlink` | 显示/输入/音频桥 |
| `/lzcapp/document/<user>` | `/lzcapp/document` | 用户文稿，`owner: "1000:1000"` |
| `/lzcapp/run/resources/skills` | 同路径 | 只读 |
| `/lzcapp/run/lightos-skill-hub/<hash>/<hash>` | `/run/lightos-skill-hub` | 只读 |
| `/lzcapp/pkg/content/skill-hub/AGENT.md` | `/opt/lightos-skill-hub/AGENT.md` | 只读单文件挂载 |
| `…/mcp-providers` | `/lzcapp/run/resources/mcp-providers` | 只读 |

可见 `bind_mounts` 支持**单文件挂载**（target 是文件路径），不只有目录。
自研内核时按 `mount --bind` 逐条处理即可，`read_only` 为 true 时加 `MS_RDONLY`。

rootfs 落在 per-user scope 下：

```
/lzcapp/var/lightos/users/<uid>/scopes/<base64(deploy_id)>/managed/<instance>/rootfs
```

---

## 5. 实例对象（`/api/list` / `/api/instances/{n}`）

```json
{
  "name": "g1", "owner_deploy_id": "cloud.lazycat.lightos.entry",
  "rootfs_dest_dir": "/path/rootfs",
  "bind_mounts": [{"source_path":"/src","target_path":"/w","read_only":true}],
  "security_level": "system", "username": "root",
  "network_mode": "nat", "network_ip": "100.64.0.10/24",
  "network_gateway": "100.64.0.1", "network_dns": "100.64.0.1",
  "mount_dev": false, "allow_disk_device": false, "vt": false, "vt_tty": 7,
  "status": "running", "pid": 3193621,
  "created_at": "2026-10-21T16:34:50+08:00",
  "cpu_usage_usec": 8983, "memory_bytes": 192512,
  "io_read_bytes": 0, "io_write_bytes": 0,
  "process_count": 1, "uptime_sec": 2,
  "init_status": "ready", "init_progress": 100
}
```

> 没有事件流。前端靠**轮询 `inspect`** 拿进度；`init_progress` 0→100。

`inspect` 对不存在实例返回 **HTTP 200 + `{"error":"实例不存在: x"}`**（其他接口是 404）。
`inspect` 不接受 `name@deploy`。

---

## 6. 其余控制端点

### `GET /api/capabilities`

```json
{"global_access":true,"network_modes":["nat","host","macvlan","ipvlan"],
 "allow_mount_dev":true,"allow_disk_device":true,"bind_mount_owner":true,
 "allowed_security_levels":["sandbox","system"],"default_security_level":"system",
 "stream_protocols":["yamux-v1"],"stream_protocol_version":"yamux-v1"}
```

### `GET /api/security-levels`

```json
{"default_security_level":"system","items":[
 {"name":"sandbox","title":"Sandbox","description":"... sysbox-runc ..."},
 {"name":"system","title":"System","description":"... runc."}]}
```

### `GET /api/system/admin-info`

```json
{"deploy_id":"cloud.lazycat.lightos.entry","domain":"lightos.<box>.heiyu.space",
 "base_url":"https://lightos.<box>.heiyu.space","features":{"bind_mount_owner":true}}
```

### `POST /api/rootfs/dockerfile/build-stream`

```json
{"context_path":"/ctx","output_path":"/out","dockerfile":"FROM ...\n"}
```

流式文本日志：`Docker build: lightos-rootfs-<nano>` → `Docker create` → `Docker export` → `Extract rootfs`。
`output_path` 已存在 → `400 {"error":"output_path already exists"}`。

`--rootfs-source-image` 就是先 build 到 `rootfs_dest_dir` 再普通 create，**不额外带字段**。

---

## 7. TCP 与转发

### 7.1 `POST /api/instances/{n}/tcp-stream`

```json
{"host":"127.0.0.1","port":22}
```

200 + yamux：`SYN s=3 "tcp-upstream\n"`、`SYN s=5 "tcp-downstream\n"`。
目标不通 → `502 {"error":"connection refused"}`。

### 7.2 `forward -R`

```http
POST /api/instances/{n}/tcp-reverse-listeners
{"session_id":"<uuid4>","listen_host":"127.0.0.1","listen_port":15999}
```

返回 200 JSON（客户端只用状态码）。随后挂一条流等待实例侧来连接：

```http
POST /api/tcp-reverse-listeners/{session_id}/accept-stream
Content-Length: 0
```

响应是 octet-stream + yamux，同样是 `control` / `tcp-upstream` / `tcp-downstream`。

### 7.3 `forward -L` / `-D`

无服务端端点：本地 listen（或 SOCKS5），每个连接复用 7.1 的 `tcp-stream`。

---

## 8. 状态机与错误文案

| 操作 | 结果 |
| --- | --- |
| `start`（已 running） | `{"ok":true,"message":"started"}` 幂等 |
| `stop`（已 stopped） | `{"ok":true,"message":"stopping"}` 幂等 |
| `delete`（不存在） | `404 {"error":"instance not found"}` |
| `delete`（运行中） | `{"error":"instance must be stopped before delete"}` |
| `create`（同名） | `400 {"error":"bundle already exists"}` |
| `build`（输出已存在） | `400 {"error":"output_path already exists"}` |
| `/api/create` 名字非法 | `{"error":"name must be lowercase letters, numbers, or hyphen"}` |
| security_level 非法 | `{"error":"invalid security_level"}` |
| network_mode 非法 | `{"error":"network_mode must be nat, host, macvlan, or ipvlan"}` |
| rootfs 目录不存在 | `{"error":"rootfs_dest_dir does not exist"}` |
| rootfs 无 systemd | `{"error":"systemd init not found in image"}` |

---

## 9. 实例内部（实测）

```
PID 1 = /sbin/init（systemd）
CapEff = 000001ffffffffff
/ = btrfs 子卷上的 rootfs 目录
sandbox → sysbox-runc（/sys 为 sysboxfs）
system  → runc
nat 网络 → 100.64.0.x/24，网关/DNS 100.64.0.1
```

---

## 9.5 资源发现位置（LPK 容器内）

平台把已安装应用的资源**解到 `/lzcapp/run/resources/`**，lightos-admin 从这里读 provider：

```
/lzcapp/run/resources/lightos.webshell/<pkg-id>/<name>/webshell-provider.json
/lzcapp/run/resources/mcp-providers/<pkg-id>/<name>/mcp.yml
/lzcapp/run/resources/skills/<pkg-id>/<skill>/SKILL.md
```

实测：

```
cloud.lazycat.lightos.entry  → {"support_home": true,  "root_path": "/webshell/"}
cloud.czyt.webshell.demo     → {"support_home": false, "root_path": "/"}
```

所以 provider 没出现在列表时，直接看这个目录有没有你的 pkg-id 就能定位是"没导出"还是"没安装"。

---

## 10. 与 WebShell provider 的关系

provider 只用得到 §2 里的 `ps`、`system admin-info`、`exec`、`exec -i/-ti`、`forward`。
其余端点属于 lightos-admin 内部；第三方 provider 不应直接调用 `/api/*`，应走 `lightosctl` 或
`/unsafe_api/webshell/*`、`/unsafe_api/publish/*`。

自研内核时，实现 §2 全部端点 + §4 的 yamux 命名流即可让现有 UI 与所有 provider 原样运行。

---

## 11. 不依赖 LightOS：自研实例运行时的做法

平台不要求 LPK 依赖 LightOS。要自己做"实例"这一层，有三条路，按需要选：

### 11.1 只有普通 LPK（零特权）

```yaml
# package.yml
package: cloud.czyt.myapp
version: 0.1.0
name: MyApp
min_os_version: v1.5.2
permissions:
  required: []          # 不需要 lightos.*
locales:
  zh: { name: MyApp }
```

```yaml
# lzc-manifest.yml
application:
  subdomain: myapp
  routes:
    - /=http://127.0.0.1:8080
services:
  app:
    image: registry.lazycat.cloud/xxx/myapp:1.0.0
```

能拿到的平台能力：路由/域名、登录、多用户、`/lzcapp/var` 持久卷、`/lzcapp/run/sys/lzc-apis.socket` 的 gRPC。
拿不到的：任何"持久 Linux 实例"、`runc`、宿主机网络。

### 11.2 自研实例运行时（替代 LightOS）

前提：需要宿主机特权，普通 LPK 容器做不到。

| 手段 | 代价 |
| --- | --- |
| `compose_override` 挂宿主 socket / 设备 | 文档明示"风险接近最高权限" |
| `run_as` + `network_mode: host` + `device.block` | 仍需在目标机验证 |
| 依赖宿主已有的 `runc` / `sysbox-runc` | 需自行确认存在性（LightOS 的 `cde` 镜像带） |

最小内核要实现的，就是本文 §2 + §4 的接口：

```
unix:///lzcapp/run/sys/<your-core>.sock
  GET  /api/list | /api/instances/{n} | /api/capabilities …
  POST /api/create | /api/start | /api/stop | /api/delete
  POST /api/instances/{n}/exec-stream   → yamux(control/exec-stdin/exec-stdout/exec-stderr/exec-pty)
```

实例本身 = `overlay(lowerdir=source_dirs+rootfs, upperdir/workdir)` + `runc/sysbox-runc run` + `nsenter` 进 pid 执行。
`create` 的字段可以完全照抄本文 §3，这样任何现成的 `lightos.webshell` provider 都能接你的运行时。

### 11.3 想被 `lightos-admin` 发现

导出资源即可，不要求你的运行时和 LightOS 相同：

```yaml
# lzc-build.yml
resource_exports:
  - kind: lightos.webshell
    source: ./resources/lightos.webshell
```

```json
// resources/lightos.webshell/default/webshell-provider.json
{ "support_home": false, "root_path": "/" }
```

平台把它解到 `/lzcapp/run/resources/lightos.webshell/<pkg-id>/<name>/`，`lightos-admin` 从这里读取并打开
`https://<provider>/<?name=<name>@<owner_deploy_id>>`。这条**资源导出契约是平台公开的**，与 LightOS 实现无关。

### 11.4 选择建议

1. 先做普通 LPK（11.1），验证产品形态；这一步零依赖、可直接上架。
2. 需要持久环境且能接受"用户装 LightOS"→ 走 `lightos.manage` + `lightosctl`（成本最低）。
3. 只有需要自定义 cgroup/快照/GPU 分配时才做 11.2，并优先复用 §3/§4 的字段与流名，保持生态兼容。
