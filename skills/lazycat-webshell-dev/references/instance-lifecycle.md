# 实例生命周期全流程（实测）

> 覆盖：rootfs → 创建 → 初始化 → 开机自启 → 登录用户与密码 → 预装软件 → 停止/删除。
> 所有脚本片段来自 `lzclightos-lpk` 内嵌常量（`strings` 提取）+ `lightosctl` 反汇编。

---

## 0. 全景

```
① 准备 rootfs        docker build → docker export → tar -x    （§1）
② create             写 instance 记录 + overlay + bundle      （§2）
③ start              runc run /sbin/init + systemd            （§3）
④ 首启初始化          lightos-setup.service（inside）          （§4）
⑤ 开机自启           由调用方保证（runtime 重启后重新 start）   （§5）
⑥ 用户名/密码        seed.env → firstboot 脚本                 （§6）
⑦ 预装软件           LIGHTOS_PKG_* → apt/pacman/npm            （§7）
⑧ SSH                实例内 sshd + 宿主转发，两个独立开关       （§8）
⑨ 停止/删除          SIGTERM → runc delete → 删目录            （§9）
```

**关键认知**：所有"进入 rootfs 做事"的动作都发生在**已启动的实例内部**（`nsenter` / systemd service 里），
宿主侧没有 `chroot` 调用。

---

## 1. 准备 rootfs

```sh
docker build -t lightos-rootfs-<nano> <context>          # 需含 systemd
cid=$(docker create lightos-rootfs-<nano>)
docker export "$cid" | tar -x -C <rootfs>
docker rm "$cid"; docker rmi lightos-rootfs-<nano>
```

校验：`<rootfs>/sbin/init` 存在且可执行，否则 `create` 报 `systemd init not found in image`。

支持的基础镜像（UI 预置，均已验证）：

```
library/archlinux:latest   library/debian:bookworm
library/debian:stable      library/debian:testing
library/ubuntu:26.04       omarchy:4.0.4
```

---

## 2. create：写哪些文件

```
<instances>/<name>/
├── rootfs/            # 读写根（或 overlay 的 merged 视图）
├── upper/             # overlay upperdir
├── work/              # overlay workdir
└── runc/
    ├── config.json    # OCI bundle，见 self-hosted-runtime.md §5
    └── rootfs -> ../rootfs
```

实例目录之外只有一份清单：

```
<instances>/instances.json
{
  "instances": [
    {
      "name":"g1", "owner_deploy_id":"...",
      "rootfs_dest_dir":"<instances>/g1/rootfs",
      "rootfs_source_dirs":[],
      "security_level":"system", "network_mode":"nat", "username":"czyt",
      "mount_dev":false, "allow_disk_device":false, "vt":false,
      "bind_mounts":[], "created_at":"2026-10-21T16:34:50+08:00",
      "status":"stopped", "pid":0
    }
  ]
}
```

写入方式：**临时文件 + `rename` 原子替换**，并在文件头加 `version` 字段便于迁移。

---

## 3. start：提交 / 启动实例

```sh
runc create --bundle <instances>/<name>/runc <name>
runc start <name>
pid=$(runc state <name> | jq .pid)
```

bundle 的 `config.json` 关键项（完整见 self-hosted-runtime.md §5）：

| 字段 | 值 |
| --- | --- |
| `process.args` | `["/sbin/init"]` |
| `process.env` | `PATH`/`HOME=/root`/`container=systemd`/`TERM=xterm` |
| `process.capabilities` | system: `1fffbffffff`；sandbox: `1ffffffffff` |
| `root.path` | 绝对路径 |
| `linux.namespaces` | pid/mount/uts/ipc/cgroup（+network 除 host 外）（+user 仅 sandbox） |
| `mounts` | proc / dev(tmpfs 64m) / dev/pts / dev/shm / run(tmpfs 128m) / sys |

**"提交"其实只有一步**：把 bundle 交给 `runc create`。runc 自己负责 `pivot_root`、cgroup、seccomp——
你不需要手写 `chroot()`。

---

## 4. 首启初始化：`lightos-setup.service`

实测（实例内部）：

```ini
[Unit]
Description=LightOS first boot setup
ConditionPathExists=/etc/lightos/seed.env

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lightos-setup.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
```

脚本开头：

```sh
#!/usr/bin/env bash
set -euo pipefail

if [ -f /var/lib/lightos/initialized ]; then
  exit 0            # 幂等：第二次启动直接退出
fi

mkdir -p /var/lib/lightos
dbus-uuidgen --ensure=/etc/machine-id

set -a
if [ -f /etc/lightos/seed.env ]; then
  . /etc/lightos/seed.env      # 读取用户名/密码/预装开关
fi
set +a
```

**这就是"写哪些配置文件"的核心答案**：

| 文件 | 谁写 | 何时读 |
| --- | --- | --- |
| `/etc/lightos/seed.env` | 宿主侧 before start（从 `create` 参数生成） | `lightos-setup.sh` 首启 |
| `/etc/lightos/*.env` | 后者（remote-desktop、local-desktop） | 对应 service |
| `/var/lib/lightos/initialized` | 脚本自己（结束时写） | 每次启动检查，保证幂等 |
| `/etc/machine-id` | `dbus-uuidgen` | systemd/dbus |

---

## 5. 开机自启（核心：runtime 负责，不是实例负责）

LightOS 的做法（反汇编 `lightos-admin` 的 `startOwnedInstancesAutostartCoordinator`）：

```
平台启动 → lightos-admin 起 → 读 instances.json
  → 对所有 status==running 且 owned by 当前 app 的实例
  → 并发执行 start
  → 失败重试（3 次，间隔递增）
```

也就是说：**实例本身不需要 `systemctl enable` 任何东西**。
`auto_start` 这个布尔值存在于**平台的应用实例配置**里（`AppInfo.auto_start`），不是实例内部。

自研时对应做法：

```
你的 core 启动 → 读 instances.json
  → 对每个 status==running 的实例执行 start（§3）
  → 若实例目录存在但 status==stopped，保持 stopped
  → 每完成一个，更新 init_status
```

注意：不要用 `runc restore` 做 checkpoint 恢复；LightOS 是**重新 start**。

---

## 6. 用户名与密码

`create` 时把 `username` 写进 instances.json，宿主侧在 start 前生成：

```sh
# 宿主侧（写进 rootfs，只在首启前）
install -d <rootfs>/etc/lightos
cat > <rootfs>/etc/lightos/seed.env <<EOF
LIGHTOS_USERNAME=czyt
LIGHTOS_PASSWORD='<明文，仅首启>'
LIGHTOS_PKG_KDE=0
LIGHTOS_PKG_XFCE=0
LIGHTOS_PKG_GNOME=0
LIGHTOS_PKG_CLAUDE=0
EOF
chmod 600 <rootfs>/etc/lightos/seed.env
```

实例内处理（`lightos-setup.sh`）：

```sh
username="${LIGHTOS_USERNAME:-root}"

# 1. 用户不存在则创建；Ubuntu 镜像要把自带的 ubuntu(1000) 改名
if ! id "${username}" >/dev/null 2>&1; then
  distro=$(sed -n 's/^ID=//p' /etc/os-release 2>/dev/null | tr -d '"')
  if [ "$distro" = ubuntu ] && [ "$(id -u ubuntu 2>/dev/null || true)" = 1000 ]; then
    usermod -l "$username" ubuntu
    groupmod -n "$username" ubuntu 2>/dev/null || true
    usermod -d "/home/$username" -m "$username"
  else
    useradd -m -U -s /bin/bash "$username"
  fi
fi

# 2. 组
for g in sudo wheel; do getent group "$g" >/dev/null 2>&1 || groupadd "$g"; done
usermod -aG wheel,sudo "$username"
getent group audio >/dev/null 2>&1 && usermod -aG audio "$username"

# 3. 密码（SHA512，无明文留存）
if [ -f /etc/login.defs ]; then
  sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/' /etc/login.defs
fi
if [ -n "${LIGHTOS_PASSWORD}" ]; then
  echo "${username}:${LIGHTOS_PASSWORD}" | chpasswd -c SHA512
fi

# 4. sudo
mkdir -p /etc/sudoers.d
printf '%s\n' '%wheel ALL=(ALL:ALL) ALL' '%sudo ALL=(ALL:ALL) ALL' > /etc/sudoers.d/90-lightos
chmod 0440 /etc/sudoers.d/90-lightos

# 5. 删除明文密码
rm -f /etc/lightos/seed.env
touch /var/lib/lightos/initialized
```

关键点：

- **`seed.env` 用完必须删**，它是明文密码的唯一载体
- `root` 用户不需要密码设置（交互登录走 SSH 或 `lightosctl exec`）
- Arch 的 `wheel`、Debian 的 `sudo`，两个组都建，避免发行版差异

---

## 7. 预装软件

### 7.1 开关（写进 seed.env）

```
LIGHTOS_PKG_KDE=0|1        KDE Plasma
LIGHTOS_PKG_XFCE=0|1       XFCE
LIGHTOS_PKG_GNOME=0|1      GNOME（Ubuntu 用 LIGHTOS_PKG_UBUNTU_GNOME 兼容）
LIGHTOS_PKG_CLAUDE=0|1     Claude CLI + settings.json 的 tui=default
```

UI 里还有这些（通过 `build` 阶段的 Dockerfile 实现，不是首启）：

```
开发基础工具    build-essential / base-devel
Golang          + /etc/profile.d/golang.sh（GOPROXY=https://goproxy.cn,direct）
Node 与 NPM
常用 CLI 工具
hclient-cli     下载当前架构二进制到 /usr/local/bin/hclient-cli
yay             pacman -S --noconfirm --needed yay，失败则构建 yay-bin
Codex CLI       npm install -g @openai/codex
Claude CLI      npm install -g @anthropic-ai/claude-code
```

### 7.2 安装方式（实例内，按包管理器分支）

```sh
# Debian/Ubuntu
apt-get update -y
apt-get -o "DPkg::Lock::Timeout=600" install -y --no-install-recommends "$@"
apt-get clean && rm -rf /var/lib/apt/lists/*

# Arch
pacman -Sy --noconfirm --needed "$@"

# Arch 的 keyring（镜像里经常坏）
if [ ! -s /etc/pacman.d/gnupg/pubring.kbx ]; then
  rm -rf /etc/pacman.d/gnupg
  install -d -m 700 /etc/pacman.d/gnupg
  pacman-key --init && pacman-key --populate archlinux
fi
```

### 7.3 镜像源（默认 USTC / TUNA）

```
Arch      /etc/pacman.d/mirrorlist        → https://mirrors.ustc.edu.cn/archlinux/
Arch 扩展  /etc/pacman.conf [archlinuxcn] → https://mirrors.ustc.edu.cn/archlinuxcn/
Ubuntu     /etc/apt/sources.list          → https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Debian     /etc/apt/sources.list          → https://mirrors.tuna.tsinghua.edu.cn/debian
Go         /etc/profile.d/golang.sh       → GOPROXY=https://goproxy.cn,direct
NPM        npm config set registry        → 大陆源
```

---

## 8. SSH：两层访问，别混

LightOS 把 SSH 拆成**互不依赖的两层**。混在一起写会出两类 bug：端口冲突、以及"关了 SSH 还在监听"。

| 层 | 谁负责 | 开关字段 | 落盘位置 |
| --- | --- | --- | --- |
| 实例内 `sshd` | **所属应用**（LightOS 自己实现） | `enable_ssh` + `ssh_port` | `/etc/lightos/lpk-ssh.env` → `/etc/ssh/sshd_config.d/lightos-lpk.conf` |
| 宿主侧端口转发 | 可跨应用管理 | `ssh_forward_enabled` / `ssh_forward_port` / `ssh_forward_target_port` / `ssh_forward_target_selector` | 只在 runtime 状态里，不落盘 |

宿主侧只做 `listen → 转发到实例 IP:port`，**不启动 sshd**。实例内 `sshd` 关掉时，
转发即使开着也只会得到 "SSH target is not reachable"。

### 8.1 实例内 sshd：`lightos-lpk-ssh-setup.sh`

实测脚本（节选，`/usr/local/bin/`，由同名 oneshot service 调用）：

```sh
#!/usr/bin/env bash
set -euo pipefail

env_file="/etc/lightos/lpk-ssh.env"
if [ -f "${env_file}" ]; then set -a; . "${env_file}"; set +a; fi

enabled="${LIGHTOS_LPK_SSH_ENABLE:-0}"          # 默认关闭
requested_port="${LIGHTOS_LPK_SSH_PORT:-22}"
network_mode="${LIGHTOS_LPK_SSH_NETWORK_MODE:-host}"
listen_port="22"
# 只有 host 网络才允许自定义端口；nat 下固定 22
if [ "${network_mode}" = "host" ] && [ -n "${requested_port}" ]; then
  listen_port="${requested_port}"
fi

if [ "${enabled}" != "1" ]; then
  stop_ssh_service          # disable --now + stop
  exit 0
fi

# 1. 缺 openssh 就装（apt / pacman，Arch 先修 keyring）
ensure_openssh
# 2. 运行时目录
mkdir -p /run/sshd /var/run/sshd /etc/ssh/sshd_config.d
# 3. 确保主配置 include 了 drop-in 目录
ensure_sshd_include      # 把 'Include /etc/ssh/sshd_config.d/*.conf' 插到首行
# 4. 生成缺失的主机密钥
ssh-keygen -A

# 5. 写覆盖配置
cat > /etc/ssh/sshd_config.d/lightos-lpk.conf <<EOF
Port ${listen_port}
PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication yes
ChallengeResponseAuthentication no
PubkeyAuthentication yes
UsePAM yes
EOF

# 6. 等服务真起来（不是看 systemctl 返回码）
if ssh_port_ready; then exit 0; fi
wait_for_systemd_bus
systemctl daemon-reload || true
systemctl reset-failed "${svc}.service" >/dev/null 2>&1 || true
systemctl restart "${svc}.service"
ssh_port_ready
```

就绪探测（**这是"启动成功"的判据**，不要用 `systemctl is-active`）：

```sh
ssh_port_ready() {
  command -v ssh-keyscan >/dev/null 2>&1 || return 1
  timeout 3 ssh-keyscan -T 2 -t ed25519,ecdsa,rsa -p "${listen_port}" 127.0.0.1 >/dev/null 2>&1
}
```

服务名兼容（Debian 叫 `ssh`，Arch 叫 `sshd`）：

```sh
resolve_ssh_service() {
  for svc in ssh sshd; do
    for d in /usr/lib/systemd/system /lib/systemd/system /etc/systemd/system; do
      [ -f "$d/${svc}.service" ] && { echo "${svc}"; return 0; }
    done
  done
  return 1
}
```

端口探测（UI 用它校验"配置的目标端口"和"实际 sshd 端口"是否一致）：

```sh
detect_ssh_port() {
  if command -v sshd >/dev/null 2>&1; then
    sshd -T 2>/dev/null | awk '$1=="port"{print $2; exit}'
  fi
  # 回退：读 sshd_config 与 drop-in，取最后一个 Port
}
```

### 8.2 密码：与系统登录密码**相互独立**

UI 文案原文："默认关闭，密码独立于系统/微服登录密码；修改会关闭已有 SSH，不关闭浏览器终端。"
"新密码非空即可；留空沿用当前密码。"

实测行为：

- `create` 只带 `username`，**不带密码**
- 首次开启 SSH 时如果没有独立 SSH 密码，提示 `set an independent SSH password first`
- 密码只存在于请求内存，不写浏览器存储
- 变更密码会**先停 sshd**，再设新密码、再启动（`SSH password processing busy` 是并发保护）

自研时最小实现：

```sh
# 宿主侧：把明文经 stdin 传给实例，不要进 argv / 日志
printf '%s\n' "$SSH_PASSWORD" | nsenter -t "$PID" -m -p -- \
  sh -c 'chpasswd -c SHA512'   # 或用 usermod -p "$(openssl passwd -6 ...)"

# 设完立刻停用旧会话，避免旧凭据继续可用
nsenter -t "$PID" -m -p -- systemctl restart "$(ssh_svc)"
```

> 别把 SSH 密码塞进 `/etc/lightos/seed.env`：那个文件是**首启系统用户**用的，
> 首启结束就被删；SSH 密码是**运行期可改**的独立凭据。

### 8.3 宿主侧转发：字段与校验

`create` / `/api/instance/update` 里与转发相关的四个字段：

```
ssh_forward_enabled          bool
ssh_forward_port             int   宿主监听端口（1024–65535）
ssh_forward_target_port      int   实例内目标端口（通常 = 实际 sshd 端口）
ssh_forward_target_selector  string 目标实例选择器（可跨应用）
```

实测校验链（`lightos-admin` 的 `apiProxy` 方法名，可直接当规格）：

| 方法 | 职责 |
| --- | --- |
| `validateManagedSSHPortState` | 端口区间、是否与保留端口冲突 |
| `findReservedSSHForwardPortOwner` | 宿主端口是否已被别的实例占用 |
| `findReservedSSHServicePortOwner` | 实例内 sshd 端口是否重复 |
| `findHostNetworkSSHForwardTargetOwner` | host 网络下目标端口归属 |
| `checkSameInstanceManagedPortConflict` | 同一实例的 sshd 端口与转发目标端口互斥 |
| `clearSSHForwardForHostPortTakeover` | 端口被接管时清理旧转发 |
| `clearSSHForward` | 关闭转发（禁用 SSHD 时连带） |

对应的用户可见错误：

| 文案 | 触发 |
| --- | --- |
| `SSH port must be between 1024 and 65535` | 端口越界 |
| `SSH port is reserved or already in use` | 宿主端口被占 |
| `port is already in use on host network` | host 网络端口冲突 |
| `Host network SSHD port is required` | 切到 host 但没给 `ssh_port` |
| `Configured SSH forward target port {n} does not match detected SSHD port {m}` | 配置与实际不一致 |
| `SSH forward is not ready.` / `SSHD is not ready.` | 探测未通过 |
| `Disabling SSHD also disables SSH forwarding.` | 两者联动的提示 |

**联动规则**：`enable_ssh=false` ⇒ `ssh_forward_enabled` 必须一起关；反之不成立
（可以只做宿主转发，指向别的应用管理的实例）。

### 8.4 实例内 sshd 的默认值

| 项 | 默认 |
| --- | --- |
| `enable_ssh` | `false` |
| `ssh_port` | 22（host 网络可改，nat 固定 22） |
| `PermitRootLogin` | `yes` |
| `PasswordAuthentication` | `yes` |
| `PubkeyAuthentication` | `yes` |
| `UsePAM` | `yes` |
| `ChallengeResponseAuthentication` | `no` |

> 这几条比发行版默认宽松（Debian/Arch 默认禁止 root 登录）。LightOS 是**单用户设备**模型，
> 访问控制在 LightOS 账号层，不在 sshd 层。自研时若面向多租户，必须收紧。

### 8.5 自研时的最小 SSH 实现

```
1. rootfs 里预装 openssh（或首启时装）
2. 首启后写 /etc/lightos/lpk-ssh.env：
     LIGHTOS_LPK_SSH_ENABLE=1
     LIGHTOS_LPK_SSH_PORT=<ssh_port>
     LIGHTOS_LPK_SSH_NETWORK_MODE=<network_mode>
3. 放 lightos-lpk-ssh-setup.sh + oneshot service
4. start 完成后用 ssh-keyscan 探活，把 ready/pending/error 写回状态
5. 宿主转发单独实现：监听 → 连实例 IP:port → 双向 copy
```

**不要**把 sshd 做成 PID 1 或容器入口：实例的 PID 1 必须是 `/sbin/init`，
否则 systemd 起不来，`enable_ssh` 也没法热切换。

### 8.6 SSH 相关状态标记（脚本与上层约定）

```
__LIGHTOS_SSH_STATUS__:ready
__LIGHTOS_SSH_STATUS__:pending
__LIGHTOS_SSH_STATUS__:missing
__LIGHTOS_SSH_STATUS__:error
__LIGHTOS_SSH_DETECTED_PORT__:<port>
__LIGHTOS_LPK_SSH_EXIT__:<code>
__LIGHTOS_SYSTEMCTL_EXIT__:<code>
```

上层解析这些标记决定卡片显示 "SSH 已就绪 / 正在启动 / 已关闭 / 启动失败"，
不要靠解析人类可读的日志文本。

---

## 9. 停止与删除

```
stop
  1. runc kill <name> SIGTERM
  2. 等 5s（systemd 需要时间收尾）
  3. runc delete --force <name>
  4. instances.json: status=stopped, pid=0

delete
  1. 必须 stopped，否则 400 instance must be stopped before delete
  2. umount overlay（若有）
  3. rm -rf <instances>/<name>
  4. 从 instances.json 移除
```

---

## 10. 自研时最少要复制的东西

| 环节 | 必须做 | 可延后 |
| --- | --- | --- |
| rootfs | `docker build+export` | 镜像源切换 |
| create | 目录 + instances.json | overlay 多层 |
| start | bundle + runc create/start | 统计字段 |
| 首启 | seed.env + useradd + chpasswd | 桌面/CLAUDE 预装 |
| 自启 | 启动时重放 status==running | 失败重试策略 |
| 停止 | SIGTERM → delete | cgroup 清理 |
| 删除 | 要求先 stop | overlay umount 加固 |
| SSH | sshd 脚本 + 探活 | 宿主转发 |

---

## 11. 常见错误

| 现象 | 原因 |
| --- | --- |
| 首启脚本每次都跑 | 忘了写 `/var/lib/lightos/initialized` |
| `useradd` 报 uid 1000 已存在 | Ubuntu 镜像自带 `ubuntu` 用户，需先 `usermod -l` |
| `pacman -S` 报签名错误 | 没重建 `pacman.d/gnupg` |
| 密码改了但不生效 | `chpasswd -c SHA512` 需要 `login.defs` 的 `ENCRYPT_METHOD SHA512` |
| 重启后实例全没了 | 没实现 §5 的 autostart 重放 |
| `seed.env` 泄漏 | 用完没 `rm`，且它含明文密码 |
| 实例卡在 starting | systemd 没起来；用 `nsenter ... systemctl is-system-running` 查 |
| SSH 显示就绪但连不上 | 只看了 `systemctl is-active`，没做 `ssh-keyscan` 探活 |
| 自定义 SSH 端口不生效 | `network_mode` 不是 host，脚本强制回 22 |
| 关了 SSH 转发还在 | 只改了 `ssh_forward_enabled`，没停 listener |
