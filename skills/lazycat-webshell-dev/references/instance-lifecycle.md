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
⑧ 停止/删除          SIGTERM → runc delete → 删目录            （§8）
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

## 8. 停止与删除

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

## 9. 自研时最少要复制的东西

| 环节 | 必须做 | 可延后 |
| --- | --- | --- |
| rootfs | `docker build+export` | 镜像源切换 |
| create | 目录 + instances.json | overlay 多层 |
| start | bundle + runc create/start | 统计字段 |
| 首启 | seed.env + useradd + chpasswd | 桌面/CLAUDE 预装 |
| 自启 | 启动时重放 status==running | 失败重试策略 |
| 停止 | SIGTERM → delete | cgroup 清理 |
| 删除 | 要求先 stop | overlay umount 加固 |

---

## 10. 常见错误

| 现象 | 原因 |
| --- | --- |
| 首启脚本每次都跑 | 忘了写 `/var/lib/lightos/initialized` |
| `useradd` 报 uid 1000 已存在 | Ubuntu 镜像自带 `ubuntu` 用户，需先 `usermod -l` |
| `pacman -S` 报签名错误 | 没重建 `pacman.d/gnupg` |
| 密码改了但不生效 | `chpasswd -c SHA512` 需要 `login.defs` 的 `ENCRYPT_METHOD SHA512` |
| 重启后实例全没了 | 没实现 §5 的 autostart 重放 |
| `seed.env` 泄漏 | 用完没 `rm`，且它含明文密码 |
| 实例卡在 starting | systemd 没起来；用 `nsenter ... systemctl is-system-running` 查 |
