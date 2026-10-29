# 桌面、Hyprland 与 Quickshell

## 1. 从“能出画面”到完整桌面

桌面元包还要覆盖：登录/会话管理、音频、网络、通知、认证代理、屏幕锁定、空闲/休眠、portal、剪贴板、截图/录屏、输入法、字体、缩放、无障碍、默认应用及电源菜单。每项标明进程所有者与启停方式，防止重复 daemon。

| 组件 | 职责 | 常见遗漏 |
|---|---|---|
| Hyprland | Wayland compositor、窗口/显示器/输入 | 不是登录管理器、网络管理器或完整 shell |
| Quickshell | Qt/QML 面板、栏、通知/锁屏等自定义 UI | 不自带通用发行版安装/升级后端 |
| UWSM/systemd user | 会话环境、生命周期、用户服务 | 环境初始化顺序、重复自启动、会话退出后残留 |
| xdg-desktop-portal | 文件选择、截屏/投屏等跨应用接口 | backend 与会话不匹配，多个实现争抢 |
| polkit agent | 展示授权提示 | UI 不等于后端权限校验 |
| PipeWire/WirePlumber | 音频/媒体路由 | 服务没启用、UCM/固件缺失、扬声器保护 |

## 2. 多桌面用会话分层

Hyprland、Plasma、GNOME 分别有包清单、session entry、portal 选择与自启动配置。共享字体/应用/输入法，不共享互相冲突的 shell、锁屏与电源 daemon。

不要在全局 `/etc/environment` 强制 `XDG_CURRENT_DESKTOP=Hyprland`；Plasma 登录后也会继承。通过 session/UWSM、systemd user environment 和会话专属配置传递变量。验证 Flatpak、文件选择、屏幕共享以及 GTK/Qt 应用。

默认提供显示器自动配置，保留用户覆盖；测试 HiDPI、多屏热插拔、混合刷新率与 XWayland。输入法检查 Fcitx5/IBus 与 Wayland text-input、候选框、终端、浏览器、Electron；“设置中文 locale”不等于有可用中文输入。

## 3. Omarchy 的默认值与用户覆盖

固定取样的 `config/hypr/hyprland.lua` 先载入 `default/hypr/bootstrap.lua`、`default.hypr.omarchy`，再载入用户 `hypr.monitors/input/bindings/looknfeel/autostart`。核心模式是**受包管理默认值先加载，用户覆盖后加载**，不需要每次更新重写用户文件。

该版本已使用 Lua；老版可能是 `.conf`。先查目标 Hyprland 与 Omarchy 版本及实际文件，不把本例硬塞进旧版解析器，也不把旧 dotfiles 的语法当成当前规范。

`default/wayland-sessions/omarchy.desktop` 通过 UWSM 启动会话；`default/uwsm/env.d/10-omarchy` 提供运行环境。这些路径属于 Omarchy 的打包契约，做独立发行版时应重新定义包路径与 namespace。

## 4. 独立 Quickshell 与已有 shell 插件是两件事

- **独立配置**：自己的 `shell.qml`、进程、服务和 API 生命周期，依照匹配版本的 Quickshell 文档开发。
- **Omarchy 插件**：加载到已有 `omarchy-shell` 中，遵循该版本 manifest、共享服务及注入属性；不能再启动一套独立 Quickshell 抢栏、通知或锁屏。

源码阅读顺序：

1. `shell/shell.qml`：`ShellRoot` 创建共享 registry、服务与配置所有者，实例通过属性注入，避免相对导入产生多份“singleton”。
2. `shell/services/PluginRegistry.qml` 与 `shell/plugins/README.md`：发现、manifest 校验、启用/禁用、用户配置边界。
3. `shell/plugins/bar/`：具体栏实现与 widget 生命周期，不把示例 widget 当 shell 主进程。
4. `bin/omarchy-launch-shell`：日志进 journal；限制崩溃重启；禁用文件监视热重载，避免软件包写入半棵源码时 reload。

本发行版新增 shell 时，明确故障降级：栏崩溃不应杀 compositor，某个插件失败不应抹掉用户配置，锁屏失败不能误报安全锁定。QML UI 不以 root 运行；特权调用经参数化、最小权限的独立后端，不把用户字符串拼成 shell。

## 5. 历史教训：容错读取不等于允许覆盖

`463a9a1d2`（2026-10-27）在 `shell/shell.qml` 增加 unreadable 标记：无法解析用户 `shell.json` 时可用默认值显示桌面，但禁止把默认值写回损坏文件。可迁移原则：**读取降级保可用；写入保护保数据**。遇到损坏配置要提示、备份和修复，不能“顺手重置”。

## 6. 验收与失败分支

| 触发条件 | 一线处理 | 仍失败 |
|---|---|---|
| UWSM 会话环境不完整 | 查 session entry、用户 journal 和环境导入顺序 | 用受测最小会话定位；不把全局 export 当修复 |
| 投屏/文件选择失败 | 查当前桌面、portal backend、D-Bus 服务 | 限定到会话 backend，重测沙箱应用 |
| Quickshell 崩溃循环 | 查 journal、匹配 QML/API 版本，禁用有问题插件 | 使用最小安全 shell，保留锁屏/注销入口 |
| 更新后用户配置损坏 | 只读降级，保留原文与备份 | 人工合并/修复，不静默重置 |

验收必须包含登录、退出、锁屏、解锁、休眠唤醒、权限提示、投屏、输入法、两种桌面切换和 shell 崩溃恢复。静态 QML 检查不替代真实 Wayland 会话。

依据：[Hyprland、Quickshell、portal](sources.md#硬件与桌面)；版本证据见[Omarchy 地图](omarchy-source-map.md)。
