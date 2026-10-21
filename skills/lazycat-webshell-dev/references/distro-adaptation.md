# 发行版适配与初始化脚本（实测提取）

> 来源：`lzclightos-lpk` 内嵌的 setup 脚本常量（`strings` 提取）。
> 结论：**没有运行在宿主机上的 chroot 逻辑**；所有"区分操作系统"的判断都发生在**已经进入 rootfs 的 shell 里**。

---

## 1. 先说结论：chroot 在哪

| 你看到的 | 实际位置 |
| --- | --- |
| "自动 chroot" | `runc` 的 `pivot_root` / `chroot`，发生在 `start` 时，**不是 LightOS 代码** |
| "区分不同操作系统" | **实例内部的 shell 脚本**，在 `exec`/setup 时跑，用 `command -v` 和 `/etc/os-release` 判断 |
| rootfs 生成 | `docker build` + `docker export`（按所选镜像） |

也就是说：**LightOS 没有"按发行版切换的 chroot 实现"**。它只有"按发行版切换的 shell 脚本"。

---

## 2. 判断方式（实测原文）

### 2.1 判断包管理器（不需要读 os-release）

```sh
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends openssh-server
  apt-get clean
  rm -rf /var/lib/apt/lists/*
  return 0
fi
if command -v pacman >/dev/null 2>&1; then
  if command -v pacman-key >/dev/null 2>&1; then
    if [ ! -s /etc/pacman.d/gnupg/pubring.kbx ]; then
      rm -rf /etc/pacman.d/gnupg
      install -d -m 700 /etc/pacman.d/gnupg
      pacman-key --init
      pacman-key --populate archlinux
    fi
  fi
  pacman -Sy --noconfirm --needed openssh
  return 0
fi
echo "openssh installation is unsupported in this rootfs" >&2
return 1
```

### 2.2 只在需要时读 os-release

```sh
lightos_init_distro="$(sed -n 's/^ID=//p' /etc/os-release 2>/dev/null | tr -d '"')"
if [ "$lightos_init_distro" = ubuntu ] && [ "$(id -u ubuntu 2>/dev/null || true)" = 1000 ]; then
  usermod -l "$username" ubuntu
  groupmod -n "$username" ubuntu
  usermod -d "/home/$username" -m "$username"
else
  useradd -m -U -s /bin/bash "${username}"
fi
```

Ubuntu 官方镜像自带 uid 1000 的 `ubuntu` 用户，LightOS 把它**改名**成目标用户名，
避免出现两个 uid 1000。这是唯一需要识别发行版的地方。

---

## 2.3 实测可用的镜像清单

UI 下拉里的预设，说明这些 rootfs 都被验证过：

```
library/archlinux:latest
library/debian:bookworm
library/debian:stable
library/debian:testing
library/ubuntu:26.04
omarchy:4.0.4
```

自研时同样建议只声明你真的测过的镜像。

## 3. 支持的发行版与对应处理

| 发行版 | 识别方式 | 特殊处理 |
| --- | --- | --- |
| Arch | `command -v pacman` | 重建 `pacman-key`（`rm -rf /etc/pacman.d/gnupg` → `init` → `populate archlinux`）；额外源 `[archlinuxcn]` |
| Debian | `command -v apt-get` | `DEBIAN_FRONTEND=noninteractive`，装完清理 `/var/lib/apt/lists` |
| Ubuntu | `/etc/os-release` 的 `ID=ubuntu` | 先改 `ubuntu` 用户为 `$username`；重写 `sources.list.d/ubuntu.sources` |
| 其它 | `command -v` 都不命中 | 输出 `unsupported ... in this rootfs` 并返回 1，**不猜** |

已验证的镜像清单（UI 下拉里）：`library/archlinux:latest`、`library/debian:bookworm`、
`library/debian:stable`、`library/debian:testing`、`library/ubuntu:26.04`、`omarchy:4.0.4`。

---

## 4. 初始化脚本（`create` 后写入实例）

实测片段（节选，顺序即执行顺序）：

```sh
# 1. Arch：重建密钥环（镜像里的 gnupg 经常不完整）
if command -v pacman-key >/dev/null 2>&1; then
  rm -rf /etc/pacman.d/gnupg
  install -d -m 700 /etc/pacman.d/gnupg
  pacman-key --init
  pacman-key --populate archlinux
fi

# 2. 创建/改名用户
if ! id "${username}" >/dev/null 2>&1; then
  lightos_init_distro="$(sed -n 's/^ID=//p' /etc/os-release 2>/dev/null | tr -d '"')"
  if [ "$lightos_init_distro" = ubuntu ] && [ "$(id -u ubuntu 2>/dev/null || true)" = 1000 ]; then
    usermod -l "$username" ubuntu
    ...
  else
    useradd -m -U -s /bin/bash "${username}"
  fi
fi

# 3. 组与 sudo
for g in sudo wheel; do getent group "$g" >/dev/null 2>&1 || groupadd "$g"; done
usermod -aG wheel,sudo "${username}"
getent group audio >/dev/null 2>&1 && usermod -aG audio "${username}"

# 4. 密码与 sudoers
[ -f /etc/login.defs ] && sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/' /etc/login.defs
[ -n "$password" ] && echo "${username}:${password}" | chpasswd -c SHA512
mkdir -p /etc/sudoers.d
printf '%s\n' '%wheel ALL=(ALL:ALL) ALL' '%sudo ALL=(ALL:ALL) ALL' > /etc/sudoers.d/90-lightos
chmod 0440 /etc/sudoers.d/90-lightos

# 5. 等 systemd
wait_for_systemd_bus() {
  for attempt in $(seq 1 30); do
    systemctl list-units >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "systemd is not ready" >&2
  return 1
}
```

**注意**：这些脚本是**在实例内部执行**的（通过 `nsenter` 或 `lightosctl exec`），
不是宿主机的 `chroot` 调用。

---

## 5. 对自研运行时的意义

你不需要实现"发行版适配的 chroot"。你只需要：

1. **rootfs 来自哪个镜像，就继承它的包管理器**——不用判断，直接 `command -v`。
2. **初始化脚本放进实例执行**（`nsenter` 后跑），而不是在宿主上 chroot。
3. **Ubuntu 的 uid 1000 冲突**要单独处理，否则 `useradd` 会失败或产生两个 1000。
4. **Arch 的 keyring 要重建**，否则任何 `pacman -S` 都会报签名错误。

一个最小可用初始化脚本：

```sh
#!/bin/sh
set -eu
username="${1:-root}"
[ "$username" = root ] && exit 0

if ! id "$username" >/dev/null 2>&1; then
  distro=$(sed -n 's/^ID=//p' /etc/os-release 2>/dev/null | tr -d '"')
  if [ "$distro" = ubuntu ] && [ "$(id -u ubuntu 2>/dev/null || echo -)" = 1000 ]; then
    usermod -l "$username" ubuntu && groupmod -n "$username" ubuntu
    usermod -d "/home/$username" -m "$username"
  else
    useradd -m -U -s /bin/bash "$username"
  fi
fi

getent group sudo  >/dev/null 2>&1 || groupadd sudo
getent group wheel >/dev/null 2>&1 || groupadd wheel
usermod -aG wheel,sudo "$username"
printf '%s\n' '%wheel ALL=(ALL:ALL) ALL' '%sudo ALL=(ALL:ALL) ALL' > /etc/sudoers.d/90-lightos 2>/dev/null || true
chmod 0440 /etc/sudoers.d/90-lightos 2>/dev/null || true
```

---

## 6. 常见误区

| 误区 | 事实 |
| --- | --- |
| LightOS 在宿主机上 `chroot` 进 rootfs 做初始化 | 不是。它在 `runc` 起的容器里 `nsenter` 执行脚本 |
| 需要按发行版写不同的 chroot 逻辑 | 不需要。只需 `command -v apt-get/pacman` 分支 |
| rootfs 必须是 Arch | 不是。`debian:bookworm` / `ubuntu:26.04` / `omarchy` 都在 UI 里 |
| `chroot` 能代替 `runc` | 不能。`runc` 提供 namespace、cgroup、seccomp；`chroot` 只有文件系统视图 |
