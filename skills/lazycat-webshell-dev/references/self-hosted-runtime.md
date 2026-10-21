# 自研 LightOS 运行时（不安装 LightOS 应用）

> 目标：不安装 LightOS 应用，自己实现实例运行时 + 自己的界面。
> 协议与 `lightos-core` 对齐（17 个 `/api/*` + yamux），因此原版 `lightosctl` 与任何 WebShell provider 都能直接对接。
> 字段均来自实测，取证方法见同目录 [lightosctl-core-contract.md](lightosctl-core-contract.md)。

---

## 0. 交付物与边界

```
你的 LPK
├── package.yml                 # 权限 + resource_exports（可选导出 lightos.webshell）
├── lzc-manifest.yml            # 自己的 UI + 自己的 core 进程
├── ui/                         # 你的界面（可选，替代 lightos-admin）
└── core/                       # ← 本文档描述的运行时
    ├── 控制面 HTTP over unix socket
    ├── 实例生命周期（overlay + runc/sysbox-runc）
    ├── 数据面 yamux（exec/tcp/forward）
    └── 统计（cgroup v2 + /proc）
```

**不依赖**：LightOS 应用、`/lzcinit/lightosctl`（可选自带一份）、`lightos-admin` 的任何内部接口。

**必依赖**：宿主机特权（起 runc）、宿主 Docker（用于 build rootfs，可选）。

## 0.1 你实际需要决定的三件事

| 决定 | 选项 A（省事） | 选项 B（完整） | 建议 |
| --- | --- | --- | --- |
| rootfs 来源 | 自带 Dockerfile，用 `docker build + export` | 复用平台 rootfs API（契约未确认） | 选 A，本文 §7 已给完整流程 |
| security_level | 只支持 `system`（runc） | 自带 `sysbox-runc` 支持 `sandbox` | 先选 A，`capabilities` 里如实只声明 `system` |
| 实例入口 | 你自己的 UI 直接调 core | 同时导出 `lightos.webshell` | 两者都做，互不冲突 |

选 A + A 就能跑通全部功能，B 只是增强。

---

## 1. 形状：一个进程 + 一个 socket

```
进程:      /lzcapp/pkg/content/<your-core>            # 静态 Go/Rust 二进制
socket:    /lzcapp/run/sys/lightos-core.sock          # 固定名，兼容原版
状态目录:  /lzcapp/var/<your-app>/instances/
日志:      stdout（平台收集）
```

启动顺序：

```
1. 读 instances.json（不存在则建空）
2. reconcile：对每个实例检查 pid 是否存活 → running / stopped
3. 清理孤儿：socket 不存在、runc state 不存在但 json 说 running
4. listen unix socket（若文件存在先删除）
5. 可选：导出 lightos.webshell，让 lightos-admin 发现你
```

---

## 2. 控制面契约（逐条实现）

公共约定：

```
HTTP/1.1 over unix socket
Host: lightos-core
X-LightOS-Internal-Deploy-ID:    <caller deploy id>
X-LightOS-Internal-Service-Name: <caller service>
→ 200 + application/json; charset=utf-8
→ 失败 4xx/5xx + {"error":"..."}
```

### 2.1 JSON 类型定义

```go
type Instance struct {
    Name            string         `json:"name"`
    OwnerDeployID   string         `json:"owner_deploy_id"`
    RootfsDestDir   string         `json:"rootfs_dest_dir"`
    RootfsSourceDirs []string      `json:"rootfs_source_dirs,omitempty"`
    BindMounts      []BindMount    `json:"bind_mounts,omitempty"`
    SecurityLevel   string         `json:"security_level"`
    Username        string         `json:"username"`
    NetworkMode     string         `json:"network_mode"`
    NetworkIP       string         `json:"network_ip,omitempty"`      // nat 才有
    NetworkGateway  string         `json:"network_gateway,omitempty"`
    NetworkDNS      string         `json:"network_dns,omitempty"`
    MountDev        bool           `json:"mount_dev"`
    AllowDiskDevice bool           `json:"allow_disk_device"`
    VT              bool           `json:"vt"`
    VTTTY           int            `json:"vt_tty,omitempty"`           // vt=true 时出现
    Status          string         `json:"status"`                     // running | stopped
    PID             int            `json:"pid"`
    CreatedAt       time.Time      `json:"created_at"`                 // RFC3339 +08:00
    CPUUsageUsec    int64          `json:"cpu_usage_usec"`
    MemoryBytes     int64          `json:"memory_bytes"`
    IOReadBytes     int64          `json:"io_read_bytes"`
    IOWriteBytes    int64          `json:"io_write_bytes"`
    ProcessCount    int            `json:"process_count"`
    UptimeSec       int64          `json:"uptime_sec"`
    InitStatus      string         `json:"init_status"`                // "ready"
    InitProgress    int            `json:"init_progress"`              // 0-100
}

type BindMount struct {
    SourcePath string `json:"source_path"`
    TargetPath string `json:"target_path"`
    ReadOnly   bool   `json:"read_only,omitempty"`
    Owner      string `json:"owner,omitempty"`   // "uid:gid"
}
```

### 2.2 路由表

| Method | Path | 请求体 | 成功响应 |
| --- | --- | --- | --- |
| GET | `/api/list` | – | `[Instance]` |
| GET | `/api/instances/{name}` | – | `Instance` |
| POST | `/api/create` | `CreateRequest` | `{"ok":true,"message":"created"}` |
| POST | `/api/start` | `{"name"}` | `{"ok":true,"message":"started"}` |
| POST | `/api/stop` | `{"name"}` | `{"ok":true,"message":"stopping"}` |
| POST | `/api/delete` | `{"name"}` | `{"ok":true,"message":"deleted"}` |
| GET | `/api/capabilities` | – | `Capabilities` |
| GET | `/api/security-levels` | – | `SecurityLevels` |
| GET | `/api/system/admin-info` | – | `AdminInfo` |
| POST | `/api/rootfs/dockerfile/build-stream` | `BuildRequest` | octet-stream 日志 |
| POST | `/api/instances/{name}/exec-stream` | `ExecRequest` | octet-stream + yamux |
| POST | `/api/exec-stream/{session}/pty-control` | `{"action":"resize","cols":N,"rows":M}` | `{"ok":true,"message":"resized"}` |
| POST | `/api/instances/{name}/tcp-stream` | `{"host","port"}` | octet-stream + yamux |
| POST | `/api/instances/{name}/tcp-reverse-listeners` | `{"session_id","listen_host","listen_port"}` | JSON |
| POST | `/api/tcp-reverse-listeners/{session}/accept-stream` | 空 | octet-stream + yamux |
| POST | `/api/vt/status` | `{"name"}` | `{"active":bool}` |
| POST | `/api/vt/activate` | `{"name"}` | `{"ok":true,"message":"activated"}` |

### 2.3 固定响应

`GET /api/capabilities`：

```json
{
  "global_access": true,
  "network_modes": ["nat","host","macvlan","ipvlan"],
  "allow_mount_dev": true,
  "allow_disk_device": true,
  "bind_mount_owner": true,
  "allowed_security_levels": ["sandbox","system"],
  "default_security_level": "system",
  "stream_protocols": ["yamux-v1"],
  "stream_protocol_version": "yamux-v1"
}
```

`GET /api/security-levels`：

```json
{
  "default_security_level": "system",
  "items": [
    {"name":"sandbox","title":"Sandbox","description":"... sysbox-runc ..."},
    {"name":"system","title":"System","description":"... runc ..."}
  ]
}
```

`GET /api/system/admin-info`：

```json
{"deploy_id":"<你的 deploy id>","domain":"<盒子域名>",
 "base_url":"https://<盒子域名>","features":{"bind_mount_owner":true}}
```

> 这三个是**给 UI 看的**，字段不对 UI 就不认。`default_security_level` 必须是你真支持的值。

### 2.4 错误矩阵（必须逐字一致）

| 情况 | 状态 | body |
| --- | --- | --- |
| 实例不存在（start/stop/delete/exec/tcp） | 404 | `{"error":"instance not found"}` |
| 实例不存在（inspect） | **200** | `{"error":"实例不存在: <name>"}` |
| 名字非法 | 400 | `{"error":"name must be lowercase letters, numbers, or hyphen"}` |
| security_level 非法 | 400 | `{"error":"invalid security_level"}` |
| network_mode 非法 | 400 | `{"error":"network_mode must be nat, host, macvlan, or ipvlan"}` |
| rootfs 目录不存在 | 400 | `{"error":"rootfs_dest_dir does not exist"}` |
| rootfs 无 systemd | 400 | `{"error":"systemd init not found in image"}` |
| 同名 create | 400 | `{"error":"bundle already exists"}` |
| 运行中 delete | 400 | `{"error":"instance must be stopped before delete"}` |
| build 输出已存在 | 400 | `{"error":"output_path already exists"}` |
| tcp 目标不可达 | 502 | `{"error":"connection refused"}` |

**注意 `inspect` 是 200**：这是原版行为，UI 按 body 判断。

---

## 3. 实例生命周期

### 3.1 `create`

```
输入: CreateRequest
1. 校验 name：^[a-z0-9-]+$
2. 校验 rootfs_dest_dir 存在，且 <dir>/sbin/init 可执行
3. 校验 security_level ∈ {sandbox, system}
4. 校验 network_mode ∈ {nat, host, macvlan, ipvlan}
5. 若 <instances>/<name> 已存在且有 rootfs → 400 bundle already exists
6. mkdir -p <instances>/<name>/{upper,work,runc}
7. 若 rootfs_source_dirs 非空:
     mount -t overlay overlay -o lowerdir=<s1>:<s2>:<dest>,upperdir=<upper>,workdir=<work> <mountpoint>
   （不加载 overlay 时可直接把 dest 当根；overlay 只是为了让多个只读层叠加）
8. 写 instances.json（status=created，init_progress=0，pid=0）
```

### 3.2 `start`

```
1. 读实例；已 running → 幂等返回 started
2. 生成 OCI bundle（见 §5）
3. runc create --bundle <bundle> <name>  → 拿容器 id
4. runc start <name>
5. 从 runc state 读 pid，写回 instances.json（status=running）
6. 后台 goroutine：nsenter 进实例执行 `systemctl is-system-running --wait`
   成功 → init_status=ready, init_progress=100
7. 失败（10s 超时）→ status=error，保留日志
```

`stop`：

```
1. 已 stopped → 幂等返回 stopping
2. runc kill <name> SIGTERM，等 5s；超时 SIGKILL
3. runc delete --force <name>
4. instances.json: status=stopped, pid=0, 统计归零
```

`delete`：

```
1. status 必须 stopped，否则 400 instance must be stopped before delete
2. 删除 <instances>/<name>
3. 从 instances.json 移除
```

### 3.3 幂等性（实测）

| 操作 | 已在目标状态 |
| --- | --- |
| start | `{"ok":true,"message":"started"}` |
| stop | `{"ok":true,"message":"stopping"}` |
| delete | 404 `instance not found` |
| create 同名 | 400 `bundle already exists` |

---

## 4. 数据面：yamux

### 4.1 帧格式

```
ver(1)=0  type(1)  flags(2)  windowID(4)  length(4)  payload
type : 0=DATA 1=WINDOW_UPDATE 2=PING 3=GO_AWAY
flags: 1=SYN 2=ACK 4=FIN 8=RST
```

使用 `github.com/hashicorp/yamux`（Go）或等价实现即可，**不要自己实现协议**。

### 4.2 exec-stream

请求：

```json
{"session_id":"<uuid4>","command":"/bin/sh","args":["-lc","echo hi"]}
{"session_id":"<uuid4>","command":"/bin/sh","tty":true,"cols":100,"rows":30}
```

响应：

```
HTTP/1.1 200 OK
Content-Type: application/octet-stream
Cache-Control: no-cache
Connection: close

<yamux 字节流>
```

服务端流程：

```
1. 校验实例 running
2. Hijack 连接（Go: http.Hijacker），写上面 4 个响应头
3. yamux.Server(conn)
4. 循环 AcceptStream，读首包作为流名（去掉结尾 \n）
      "control" / "exec-stdin" / "exec-stdout" / "exec-stderr" / "exec-pty"
5. 非 PTY：
     cmd := 构造 `<runc|nsenter> ... command args`
     stdout 管道 → exec-stdout 流；stderr → exec-stderr；exec-stdin 流 → stdin
     命令结束 → 对 5/7 发 FIN
6. PTY：
     pty.Start(cmd)  →  master 文件
     exec-pty 流 ↔ master 双向 copy
     master 关闭 → 对 exec-pty 发 FIN
7. 记住 session_id → *pty.File，供 pty-control 使用
```

### 4.3 进入实例的命令（关键）

```bash
# 非 PTY
nsenter -t <pid> -m -p -u -i -n -- <command> [args...]
# PTY
nsenter -t <pid> -m -p -u -i -n -- /bin/sh -lc <bootstrap>
```

- `sandbox` 级别额外 `-U`（user namespace）
- 切用户：`setpriv --reuid --regid --init-groups`（比 `su` 可靠）
- 载入 Catlink 环境（可选）：`[ -f /run/catlink/shell-env.sh ] && . /run/catlink/shell-env.sh`

### 4.4 pty-control

```
POST /api/exec-stream/{session_id}/pty-control
{"action":"resize","cols":107,"rows":33}
→ {"ok":true,"message":"resized"}

实现: 找 session → ioctl(master, TIOCSWINSZ, winsize{rows, cols})
```

### 4.5 tcp-stream

```json
POST /api/instances/{name}/tcp-stream  {"host":"127.0.0.1","port":22}
```

服务端：`nsenter -t <pid> -n -- <你的 dialer>` 或直接在宿主上用实例的 netns 建 TCP。
返回 yamux，流名 `tcp-upstream` / `tcp-downstream`。目标不通 → `502 {"error":"connection refused"}`。

### 4.6 forward -R

两段式：

```
POST /api/instances/{name}/tcp-reverse-listeners
{"session_id":"<uuid4>","listen_host":"127.0.0.1","listen_port":15999}
→ 200 JSON

POST /api/tcp-reverse-listeners/{session_id}/accept-stream
→ 200 octet-stream + yamux
```

服务端在实例 netns 内 `Listen`，每 accept 一个连接就在 accept-stream 的 yamux 里开一对 `tcp-upstream`/`tcp-downstream`。

---

## 5. OCI bundle（起实例的核心）

```json
{
  "ociVersion": "1.0.2",
  "process": {
    "terminal": false,
    "args": ["/sbin/init"],
    "env": ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "HOME=/root", "container=systemd", "TERM=xterm"],
    "cwd": "/",
    "capabilities": {
      "bounding": [<全部，或 sandbox 去掉 2 位>],
      "effective": [...], "permitted": [...], "ambient": []
    },
    "noNewPrivileges": false,
    "rlimits": [{"type":"RLIMIT_NOFILE","hard":1048576,"soft":1048576}]
  },
  "root": {"path": "<rootfs 绝对路径>", "readonly": false},
  "hostname": "<实例名>",
  "mounts": [
    {"destination":"/proc","type":"proc","source":"proc"},
    {"destination":"/dev","type":"tmpfs","source":"tmpfs","options":["nosuid","size=65536k","mode=755"]},
    {"destination":"/dev/pts","type":"devpts","source":"devpts","options":["nosuid","noexec","newinstance","ptmxmode=666","mode=620","gid=5"]},
    {"destination":"/dev/shm","type":"tmpfs","source":"shm","options":["nosuid","noexec","nodev","size=1048576k"]},
    {"destination":"/run","type":"tmpfs","source":"tmpfs","options":["nosuid","nodev","size=131072k","mode=755"]},
    {"destination":"/sys","type":"sysfs","source":"sysfs","options":["nosuid","noexec","nodev","ro"]}
  ],
  "linux": {
    "namespaces": [
      {"type":"pid"},{"type":"mount"},{"type":"uts"},{"type":"ipc"},{"type":"cgroup"},
      {"type":"network"}   // host 模式去掉这一行
      // sandbox 额外: {"type":"user"}
    ],
    "seccomp": {"defaultAction":"SCMP_ACT_ERRNO","architectures":["SCMP_ARCH_X86_64"],"syscalls":[...]},
    "resources": {"devices":[{"allow":false,"access":"rwm"}]},
    "maskedPaths": ["/proc/kcore","/proc/latency_stats","/proc/timer_list", ...],
    "readonlyPaths": ["/proc/asound","/proc/bus","/proc/fs","/proc/irq","/proc/sys","/proc/sysrq-trigger"]
  }
}
```

`bind_mounts` 逐条转成：

```json
{"destination":"<target_path>","type":"bind","source":"<source_path>",
 "options":["rbind","rw" 或 "ro","rprivate"]}
```

`owner: "1000:1000"` 需要在挂载前对 source 做 `chown`（或挂载后 chown target）。

---

## 6. 网络

### 6.1 nat（默认）

```
1. 创建网桥 br-lightos（若不存在）: 100.64.0.1/24
2. 创建 veth pair: veth-<name> / veth-<name>-in
3. 宿主端 veth-<name> 加入网桥
4. 容器端挪进实例 netns，改名 eth0，配 100.64.0.N/24
5. 默认路由 100.64.0.1
6. /etc/resolv.conf 用 100.64.0.1（或写实例内文件）
7. iptables -t nat -A POSTROUTING -s 100.64.0.0/24 -j MASQUERADE
```

IP 分配：从 `100.64.0.10` 起，扫描 instances.json 找空闲。

### 6.2 host

去掉 network namespace，其他相同。容器与宿主共享网络。

### 6.3 macvlan / ipvlan

在宿主物理网卡上建子接口；需要用户填网段。第一版可以返回 501 `{"error":"unsupported network_mode"}`，但 `capabilities` 里别声明支持。

---

## 7. rootfs 构建

```json
POST /api/rootfs/dockerfile/build-stream
{"context_path":"/lzcapp/cache/x/ctx","output_path":"/lzcapp/cache/x/rootfs",
 "dockerfile":"FROM ...\nRUN ...\n"}
```

服务端：

```
1. output_path 已存在 → 400 output_path already exists
2. 写 context_path/Dockerfile
3. 响应头: Content-Type: application/octet-stream（流式）
4. 执行:
     docker build -t lightos-rootfs-<nano> <context>
     docker create <tag>  → cid
     docker export <cid> | tar -x -C <tmp>
     docker rm <cid>; docker rmi <tag>
     mv <tmp> <output_path>
5. 每步日志写入响应体；完成时写 `__LIGHTOS_RESULT__:ok`
```

原版进度行的前缀是 `__LIGHTOS_RESULT__:`（反汇编确认），`lightosctl build` 会解析它。

---

## 8. 统计

| 字段 | 来源 |
| --- | --- |
| `cpu_usage_usec` | `/sys/fs/cgroup/<path>/cpu.stat` → `usage_usec` |
| `memory_bytes` | `memory.current` |
| `io_read_bytes` / `io_write_bytes` | `io.stat` 求和 |
| `process_count` | `pids.current` |
| `uptime_sec` | `now - created_at` |
| `pid` | runc state 的 Pid |

cgroup path：`runc` 默认创建在 `/sys/fs/cgroup/<container-id>`；用 `--cgroup-manager` 或 `state` 命令确认。

**实现建议**：`inspect` 每次实时读；`list` 也实时读（实例数量少，开销可忽略）。

---

## 9. 安全与隔离（按级别）

| 项 | sandbox | system |
| --- | --- | --- |
| user namespace | 有 | 无 |
| CapEff | `1ffffffffff` | `1fffbffffff` |
| `/sys` | sysboxfs 伪装 | 真实 sysfs（只读） |
| seccomp | 1 个 filter | 1 个 filter |
| NoNewPrivs | 0 | 0 |
| 可 `sudo`/`setuid` | 是 | 是 |

如果你没有 `sysbox-runc`，`sandbox` 可以用 **runc + user namespace + 严格 seccomp + 最后 chroot 到 rootfs** 近似。
但要让 `capabilities` 如实声明，避免 UI 给出误导。

---

## 10. 与上层对接

### 10.1 让原版 `lightosctl` 用你的 core

最省事：在你的 LPK 里放一份 `lzcinit`（从实测环境复制的 `bin/lightosctl`），
并在服务 environment 里设：

```yaml
environment:
  LIGHTOS_CORE_SOCKET: /lzcapp/run/sys/lightos-core.sock
```

若要与 `lightos-admin` 共存，则需要覆盖它的环境变量（不在你的控制范围内），所以更推荐**自带 `lightosctl` + 自己的 UI**。

### 10.2 被 `lightos-admin` 发现

```yaml
resource_exports:
  - kind: lightos.webshell
    source: ./resources/lightos.webshell
```

```json
{"support_home": false, "root_path": "/"}
```

平台会解到 `/lzcapp/run/resources/lightos.webshell/<pkg-id>/<name>/webshell-provider.json`。

### 10.3 自己的 UI

```yaml
application:
  subdomain: my-lightos
  routes:
    - /=http://127.0.0.1:8080          # 你的 UI + API
```

UI 直接调你的 core（同一个容器内 unix socket），不需要经过 `lightosctl`。

---

## 11. 实现顺序（可直接当任务列表）

```
□ 1. socket server + 路由骨架 + 三个只读端点（list/instances/capabilities）
□ 2. instances.json 存储 + 原子写 + 启动 reconcile
□ 3. create/start/stop/delete + overlay + OCI bundle + runc
□ 4. nsenter 执行 + PTY + yamux 四条流
□ 5. pty-control（TIOCSWINSZ）
□ 6. 静态统计（cgroup v2）
□ 7. tcp-stream
□ 8. forward -R（两段式）
□ 9. build-stream（docker）
□ 10. nat 网络
□ 11. 错误矩阵逐条对齐（用 lightosctl 回归）
□ 12. 可选：导出 lightos.webshell
```

验收脚本：拿原版 `lightosctl` 当测试客户端，跑 `ps/inspect/create/start/exec/exec -t/tcp/forward/stop/rm`，逐条比对错误与响应。

---

## 12. 从这里开始（推荐默认路径）

不要先纠结选项，按下面这条路径做，一路都能跑，后面可升级：

```
第 1 步  只做 §2 的只读端点（list / instances / capabilities）+ instances.json
         → 用原版 lightosctl 跑 `ps` 验证（此时返回空数组即可）
第 2 步  §3 的 create/start/stop/delete + §5 的 OCI bundle + runc
         → `lightosctl create g1 --rootfs <dir>` + `start` + `inspect` 通过
第 3 步  §4 的 exec-stream（先只做非 PTY 的 4 条流）
         → `lightosctl exec g1 /bin/echo ok`
第 4 步  §4.4 pty-control + `exec -t`
         → 你自己的 WebShell 或 lcmd-webshell 能开终端
第 5 步  §8 统计字段（UI 资源面板才有数）
第 6 步  §7 build-stream（这样 UI 的"创建实例"能选镜像）
第 7 步  §6.1 nat 网络（前面先用 host 网络跑通）
第 8 步  §4.5/4.6 tcp 与 forward -R
第 9 步  §10.2 导出 lightos.webshell（让 lightos-admin 也能发现你）
```

**默认取舍**（除非有明确理由才改）：

- rootfs：`docker build + export`（§7）
- security_level：只声明 `system`（runc），`capabilities.allowed_security_levels = ["system"]`
- 网络：先 `host`，再接 `nat`
- PTY：先非 PTY，再接 PTY

每一步都用**原版 `lightosctl`** 当测试客户端，它是最严格的一致性检查器。

### 最小验收命令

```bash
export LIGHTOS_CORE_SOCKET=/lzcapp/run/sys/lightos-core.sock
lightosctl ps
lightosctl capabilities
lightosctl create --name g1 --rootfs /lzcapp/cache/img/rootfs --network host --security-level system
lightosctl start g1
lightosctl inspect g1
lightosctl exec g1 /bin/echo ok
lightosctl stop g1 && lightosctl rm g1
```
