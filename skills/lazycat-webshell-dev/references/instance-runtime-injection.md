# 实例内部：平台注入了什么（实测）

> 结论全部来自在 tinycat 上创建一个 sandbox 实例后 `exec` 进去查看 `/proc`、`/`、mountinfo。
> 相关契约见 [lightosctl-core-contract.md](lightosctl-core-contract.md)。

---

## 1. 一句话结论

**实例里没有任何 lightosctl。** 它是 provider 侧（LPK 容器）的工具，`lightosctl exec` 只是从外部把命令送进去。
自研内核时，你不需要往 rootfs 里注入任何东西。

---

## 2. 实测证据

在一个 sandbox 实例里：

```
$ lightosctl exec inj1 /bin/sh -lc 'ls /lzcinit'
ls: /lzcinit: No such file or directory

$ lightosctl exec inj1 /bin/sh -lc 'command -v lightosctl'
（空）

$ lightosctl exec inj1 /bin/sh -lc 'ls /lzcapp'
ls: /lzcapp: No such file or directory

$ lightosctl exec inj1 /bin/sh -lc 'cat /proc/1/environ | tr "\0" "\n"'
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
TERM=xterm
container=private-users
HOME=/root
```

即：**没有 PATH 注入、没有 profile.d、没有 `/lzcinit`、没有 `LZC-*` 环境变量**。

---

### 线上 system 级实例（`security_level=system`）的对照

同样在 tinycat 上、`system` 级别、Arch 的实例 `xcoder`：

```
/etc/os-release     Arch Linux (rolling)
systemd             262
/proc/1/status      CapInh 0000000000000000
                    CapPrm/CapEff/CapBnd 000001fffbffffff
                    NoNewPrivs 0, Seccomp 2（有过滤器）
mountinfo           30 条
/lzcapp             document/ run/ —— 由 bind_mounts 挂进来的，不是镜像自带
/lzcinit            不存在
```

和 sandbox 实例的区别只有：无自定义 user namespace（`container=systemd` 而不是 `private-users`）、
能力集少 2 位（`1fffbffffff` vs `1ffffffffff`）。

---

## 3. 那平台“注入”了什么

不是文件，而是**运行时边界**：

| 项 | 实测值 |
| --- | --- |
| CapEff / CapPrm / CapBnd | `000001ffffffffff`（全能力） |
| NoNewPrivs | 0 |
| Seccomp | 2（有过滤器） |
| PID 1 | `/sbin/init`（systemd） |
| `/` | 宿主 btrfs 子卷上的 rootfs 目录 |
| `/sys` | sysboxfs 伪装（sandbox 级别） |
| `/dev` | tmpfs，size 64M |
| `/run` | tmpfs，128M |

所以“注入”= 用 sysbox-runc/runc 起容器 + 挂 proc/sys/dev/run + seccomp + 全部 capability。
这是容器配置，不是往镜像里塞文件。

---

## 4. 平台真正注入文件的地方（在 LPK 侧）

`lzcinit`（也就是 `/lzcinit/lightosctl`）作为 **LPK 的 init** 才做注入，而且注入到自己的容器：

```
/lzcapp/run/            manifest.yml 拷贝
/lzcapp/run/setup_script   setup_script 内容（lzc-manifest 里声明的）
/lzcapp/run/sys/        平台 API socket（lzc-apis.socket、lightos-core.sock …）
/lzcapp/run/certs/      app.crt / app.key / box.crt（mTLS）
/lzcapp/var/            持久数据
/lzcapp/cache/          可清理缓存
/lzcapp/pkg/            只读的 LPK 内容
```

启动顺序（从 `main.mainFunc` 反汇编看）：

```
flag: --version / --healthcheck / --listen :8080 / --grpc_listen :8081
      --manifest /lzcapp/run/manifest.yml / --setup-script / --user
1. parse manifest
2. InitWorkDir（chdir 到工作目录）
3. setup_script（若配置）：跑 /lzcapp/run/setup_script 或 setup_script.sh
4. inject（HTML/JS 注入、/_lzc/ 路由、auth token 端点）
5. extensions（db / dlna / files / runtime）
6. healthcheck
7. run_server（HTTP + gRPC）
```

`/lzcinit/lightosctl` 之所以能工作，是因为 **它和 init 是同一个二进制**，能直接读同一套环境变量：

```
LIGHTOS_CORE_SOCKET       覆盖 core socket
LAZYCAT_APP_DEPLOY_ID     身份头值
LAZYCAT_APP_SERVICE_NAME  身份头值
LZCAPP_API_GATEWAY_ADDRESS  平台 gRPC 地址（容器内）
```

---

## 5. 要做自己的 rootfs 时该怎么做

### 最小 rootfs（能跑 LightOS 实例）

```
必需：/sbin/init（systemd）—— 少它 create 直接报
      基础工具按需装（bash、coreutils、curl…）
不需要：lightosctl、lzcinit、任何 /lzcinit 目录
不需要：任何 LZC-* 环境变量
```

创建流程：

```sh
# 1. 准备一个 systemd 镜像，导出成 rootfs
lightosctl build --context-dir /lzcapp/cache/<ctx> /lzcapp/cache/<rootfs>
# Dockerfile: FROM registry.lazycat.cloud/lzc/lzcapp:3.20.3

# 2. 创建实例（rootfs 目录必须已存在且含 sbin/init）
lightosctl create --name g1 --rootfs /lzcapp/cache/<rootfs> \
  --network nat --security-level sandbox

# 3. 进实例（命令从外部送进去，不依赖实例内任何 lzc 文件）
lightosctl exec -ti g1 /bin/sh
```

### 自研内核时要“注入”的只有两件事

1. **rootfs 的 overlay**：`lowerdir = rootfs_source_dirs + rootfs_dest_dir`，`upperdir/workdir` 放在 bundle 下。
2. **exec 的进入方式**：`nsenter -t <pid> -m -p -u -i -n -- <cmd>`，或按 bundle 起新进程。**不要把二进制拷进 rootfs**。

---

## 6. 常见误区

| 误区 | 事实 |
| --- | --- |
| "实例里要有 lightosctl 才能 exec" | 不需要；exec 是宿主机侧拉起进程 + nsenter |
| "create 会把 lightosctl 拷进 rootfs" | 不会；实测 rootfs 里没有 `/lzcinit`、没有 `/usr/local/bin/lightosctl` |
| "平台会往实例注入环境变量" | 只注入 `container=private-users`/`HOME`/`PATH` 这几个常量 |
| "rootfs 必须是 Arch" | 不是；要求是 systemd + `/sbin/init`，Debian/Ubuntu 同样可以 |
| "实例里能调平台 gRPC" | 不能；`/lzcapp/run/sys/lzc-apis.socket` 只在 LPK 容器里 |
| "/lzcapp 是实例镜像的一部分" | 不是；它是 lightos-admin 创建实例时用 `bind_mounts` 挂进来的（catlink、document、skills） |
