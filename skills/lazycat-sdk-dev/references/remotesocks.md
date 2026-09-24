# LazyCat 远程网络编程（remotesocks）

remotesocks 是懒猫 hportal 的远程网络编程库：让 lzcapp 把「微服所在物理网络」或「任意客户端设备（hclient）所在物理网络」当作自己的网络来用——直接 dial / listen TCP / UDP / 多播。

两种使用方式：

| 方式 | 场景 | 入口 |
|------|------|------|
| lzc-sdk GetNetstack | 在目标网络中访问服务、监听端口、设备发现 | `gohelper.GetNetstack(target)` |
| 直接依赖 remotesocks | 只需要转发引擎（如 netmap 全端口转发） | `remotesocks.ForwardConn` |

仓库：
- remotesocks: https://gitee.com/linakesi/remotesocks
- netmap（官方用例）: https://gitee.com/lazycatcloud/netmap

---

## 1. GetNetstack：跨网络 dial / listen

### 背景模型

- hportal 是懒猫的去中心化虚拟隧道系统，连接微服（hserver）与用户客户端设备（hclient：手机 / PC / TV 上的懒猫客户端）。
- hserver 可在两种网络栈上提供 SOCKS5 服务（`HPortalSys.RemoteSocks` RPC）：
  - `Local`：hserver（微服盒子）所在物理网络
  - `Remote`：指定 hclient 所在物理网络（target = hclient id，底层为 hportal peer id）

### API

```go
import gohelper "gitee.com/linakesi/lzc-sdk/lang/go"

ns := gohelper.GetNetstack(target) // 返回 spec.Netstack
```

- `target = ""` → 微服（盒子）所在物理网络
- `target = <hclient id>` → 该客户端设备所在物理网络

返回的 `spec.Netstack` 与 Go 标准库 net 接口同构：

| 调用 | 作用 | 底层 SOCKS5 命令 |
|------|------|------------------|
| `DialContext(ctx, "tcp", addr)` | 访问目标网络中的 TCP 服务 | CONNECT |
| `Listen(ctx, "tcp", addr)` | 在目标网络中监听端口 | BIND |
| `DialContext(ctx, "udp", addr)` | UDP dial | 扩展 0xe2 |
| `ListenPacket(ctx, "udp", addr)` | UDP listen；多播地址 → SSDP/mDNS 发现 | 扩展 0xe3 |
| `DialContext(ctx, <other-network>, addr)` | 自定义 network（服务端注入的 dialer 决定支持范围） | `.custom` 域名编码 |

### 完整示例

```go
import (
    "context"
    gohelper "gitee.com/linakesi/lzc-sdk/lang/go"
    "gitee.com/linakesi/lzc-sdk/lang/go/common"
)

// 1. 选目标设备：ListHClients 拿到 hclient 列表
gw, _ := gohelper.NewAPIGateway(ctx)
defer gw.Close()

clients, err := gw.HClients.ListHClients(ctx, &common.ListHClientsRequest{Uid: uid})
// ⚠️ 检查点：过滤 is_online=false 的设备，不要对离线设备发起操作

// 2. 拿到跨网络 netstack（"" = 微服所在网络）
ns := gohelper.GetNetstack(clients.Hclients[0].Id)

// 3. 像标准 net 一样使用
conn, err := ns.DialContext(ctx, "tcp", "192.168.1.1:80")       // 访问目标网络里的路由器
l, err := ns.Listen(ctx, "tcp", ":8080")                        // 在目标网络中监听端口
pc, err := ns.ListenPacket(ctx, "udp", "239.255.255.250:1900")  // SSDP 多播监听
```

### 检查点

- ⚠️ 目标 hclient 必须在线（`HClient.is_online`），离线设备不要发起操作
- ⚠️ 套用超时 ctx；不要依赖内部默认超时
- ⚠️ 多播地址必须用 `ListenPacket`，不是 `Listen`
- `GetNetstack` 通过 `/lzcapp/run/sys/portal-server.socket` 调 hserver gRPC（由 lzc-runtime 鉴权），每次请求动态获取 socks server url（带缓存、失败自动刷新）；不需要自己建连接或管理地址
- 访问的是「目标设备所在物理网络能到达的地址」，不是设备本机（例如手机在咖啡厅 WiFi，则能访问咖啡厅网络里的设备）
- 返回的 listener 是「伪 listener」：每次 `Accept()` 都对应一次新的 BIND 请求

### 官方用例

- DLNA 扫描服务：`RemoteMediaPlayer.lan_region` 为空 = 微服局域网；否则为「具体客户端 peer id 的局域网」
- 说明同一模式可复制到任意「发现目标网络中设备」的场景（SSDP / mDNS / 端口扫描）

---

## 2. 转发引擎：ForwardConn（netmap 案例）

netmap 是官方 demo（全端口动态转发工具），演示「部署参数」+ remotesocks 转发引擎的组合。

### 机制拆解

1. `lzc-deploy-params.yml` 声明安装参数，让用户填 `target`（目标 IP）、`listen.port`：

```yaml
params:
  - id: target
    type: string
    name: "target"
    description: "the target IP you want forward"
  - id: listen.port
    type: string
    name: "listen port"
    default_value: "33"
    optional: true
```

2. `lzc-manifest.yml` 模板渲染（`{{ .U.target }}` 引用用户参数）：

```yaml
min_os_version: v1.3.8
application:
  upstreams:
    - location: /
      backend_launch_command: /lzcapp/pkg/content/netmap -target={{ .U.target }} -port={{ index .U "listen.port" }}
  ingress:
    - protocol: tcp
      port: {{ index .U "listen.port" }} # ingress 流量转发到应用后端的端口
      publish_port: 0-65536              # 所有端口都要（全端口转发）
      send_port_info: true               # 系统在数据流开头附 2 字节小端原始入站端口
      yes_i_want_80_443: true            # 明确声明要转发 80/443
ext_config:
  default_prefix_domain: config          # 启动器打开配置页前缀域名，避免走 ingress
```

3. Go 后端：读端口号 → dial 目标 → `remotesocks.ForwardConn` 双向转发：

```go
import (
    "context"
    "encoding/binary"
    "net"
    "strconv"

    "gitee.com/linakesi/remotesocks"
)

l, _ := net.Listen("tcp", net.JoinHostPort("0.0.0.0", listenPort))
for {
    conn, err := l.Accept()
    if err != nil {
        panic(err)
    }
    var port uint16
    binary.Read(conn, binary.LittleEndian, &port) // send_port_info 的前 2 字节

    target := net.JoinHostPort(targetIP, strconv.Itoa(int(port)))
    go func() {
        t, err := net.Dial("tcp", target)
        if err != nil {
            return
        }
        // 双向转发；返回后两个连接都会被关闭
        remotesocks.ForwardConn(context.TODO(), remotesocks.TCPBufSize, t, conn)
    }()
}
```

### 关键点

- `send_port_info: true` 是平台能力：仅 TCP 有效，系统在转发给应用的 TCP 数据流开头写入 2 字节原始入站端口（little endian uint16）（netmap 声明 `min_os_version: v1.3.8`）
- `publish_port: 0-65536` 声明全端口；80/443 需要额外的 `yes_i_want_80_443: true`
- `ForwardConn(ctx, bufsize, c1, c2)` 会双向拷贝并在结束时关闭两端；`TCPBufSize`（2048）是库内推荐缓冲
- 目标 IP 可以是「微服内可访问到的任何 IP」（转发目标在微服网络侧）

### 可扩展方向（netmap README 列出）

- 支持 UDP 端口转发
- 不同端口段转发到不同主机
- 流量统计
- 对 HTTP 流量增加自定义鉴权

---

## 3. 典型开发方向

### 跨网络访问与发现（GetNetstack）

- 局域网扫描器 / 网络拓扑：从微服或任意用户设备视角枚举设备（端口探测、指纹）
- 智能家居与投屏发现：SSDP / mDNS 多播监听，发现 DLNA 设备、打印机、IoT 网关
- 内网服务代理：把目标网络里的路由器管理页、NAS、带外管理（iLO/IPMI）通过懒猫域名 + 认证代理出来
- 远程排障工具：从「出问题的设备所在网络」做连通性检测、端口检查、服务探测

### 监控与自动化

- 家庭网络监控：定期扫描 + 变化检测（新设备接入、端口变化）→ 结合通知能力推送（见 [frontend-extensions.md](frontend-extensions.md) / [go-sdk.md#go-backend-notification](go-sdk.md#go-backend-notification)）
- 场景联动：检测到特定设备上线/下线触发动作（配合 minidb 存历史）

### 转发与代理（直接使用库）

- netmap 增强版：UDP、多目标、鉴权、统计（见上文案例）
- 通用 SOCKS5 工具：完整 client/server 实现，可架在任意隧道之上（`ServeConn` 接受任意 `io.ReadWriteCloser`）
- 跨网络调试代理：开发机连微服 socks 入口调试目标网络服务

### 与 MCP 组合

- 把网络扫描 / 发现能力做成 MCP provider 暴露给 agent（见 [mcp-resources.md](mcp-resources.md)），例如 `netmap__scan_lan`、`netmap__discover_ssdp`
- 让 agent 通过 MCP 工具在「用户设备所在网络」执行探测，再结合其他工具做决策

---

## 4. 协议与库能力速览

remotesocks 是完整的 SOCKS5 client + server 实现：

| 命令 | 值 | 说明 |
|------|----|------|
| CONNECT | 0x01 | TCP dial |
| BIND | 0x02 | TCP listen（支持多次 Accept；服务端 listener 复用 + 空闲 1 分钟自动回收） |
| UDP ASSOCIATE | 0x03 | 标准 UDP 转发 |
| ConnectUDP（扩展） | 0xe2 | UDP dial，可获取服务端与远端的真实出口地址 |
| BindUDP（扩展） | 0xe3 | UDP listen，握手后 stream 切换为 UDP 帧协议（2 字节长度 + 16 字节 IP + 2 字节端口头） |

其他：

- Custom Network：域名编码 `base64(network).base64(address).custom`，可隧道任意自定义 network（服务端通过 `SetCustomNetworkDialer` / `SetCustomNetworkAccepter` 注入实现）
- UDP 多播：BindUDP 到多播地址时自动 `ListenMulticastUDP` + 多播回环
- 客户端支持动态 proxy 地址（失败自动刷新重试）；`LocalNetstack` 支持注入自定义 `DialContextFunc`
- 安全模型：仅 NoAuth（无认证）——安全由外层（hserver 封装 + lzc-runtime 鉴权 + 隧道加密）负责，**不要裸奔在公网**
- 兼容第三方 SOCKS5 客户端，但仅限标准 CONNECT/ASSOCIATE；BIND 与 UDP 扩展只有本库 client 支持

直接使用库的 API：

```go
// server：把任意 stream 连接交给 socks server 处理
srv := remotesocks.NewRemoteSocksServer(localNetstack, nil)
srv.ServeConn(ctx, conn) // conn 可以是 libp2p stream / websocket / 任意 io.ReadWriteCloser

// client：固定地址或动态地址
c := client.NewFixedClient("socks5://127.0.0.1:1080")
c := client.NewClient(func() (string, error) { /* 动态获取 */ })
c.DialContext(ctx, "tcp", "10.0.0.1:80")

// 转发
remotesocks.ForwardConn(ctx, remotesocks.TCPBufSize, c1, c2)
```

---

## 5. 检查清单

- [ ] 跨网络操作前确认目标 hclient 在线
- [ ] 所有 dial/listen 带超时 ctx
- [ ] 多播发现用 `ListenPacket`，地址形如 `239.255.255.250:1900`
- [ ] 转发工具显式声明 `publish_port` / `send_port_info` / `yes_i_want_80_443`
- [ ] 不要把 remotesocks 直接暴露公网（NoAuth）
- [ ] 第三方客户端场景只依赖标准 CONNECT/ASSOCIATE

## 参考

- remotesocks 仓库：https://gitee.com/linakesi/remotesocks
- netmap 官方用例：https://gitee.com/lazycatcloud/netmap
- `GetNetstack` 源码：https://gitee.com/linakesi/lzc-sdk/blob/master/lang/go/rs.go
- 部署参数文档：https://developer.lazycat.cloud/spec/deploy-params.html
- TCP/UDP 4 层转发（send_port_info）：https://developer.lazycat.cloud/advanced-l4forward.html
- lzc-manifest.yml 规范：https://developer.lazycat.cloud/spec/manifest.html
