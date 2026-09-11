# Global IPv6 Disabler (global_ipv6_off)

适用于 **Magisk / KernelSU / APatch** 的模块，在开机时**全局禁用 IPv6**（Wi-Fi 与移动数据），并提供常驻守护进程防止系统在运行中重新启用 IPv6。
注意：本插件仅ColorOS16 设备OPPO FIND X8上测试并功能完整，如使用本插件请进行自测，如使用本插件造成对设备损坏与作者无关！

---

## 功能特性

- **开机即禁用 IPv6**：对所有网卡接口统一写入 `disable_ipv6 = 1`，并同时关闭 `disable_ra`、`disable_policy`。
- **常驻守护进程**（`ipv6_guard.sh`）：内核 / netd 可能在 WiFi 重连、数据切换、虚拟网卡重建时把 `disable_ipv6` 悄悄改回 `0`（IPv6 复现）。本守护循环监控并强制恢复禁用状态，确保 IPv6 一直保持关闭。
- **即时开关（toggle）**：通过模块的 `toggle` 文件实时切换 ON/OFF，无需重启。
- **action（>）快捷菜单**：通过音量键一键开关/查看状态。

---

## 文件清单

| 文件 | 作用 |
|------|------|
| `module.prop`   | 模块信息（id/名称/版本/作者/描述） |
| `service.sh`    | 开机执行：按 toggle 一次性应用开关，并启动守护进程 |
| `ipv6_guard.sh` | 常驻守护，循环监控并强制保持 IPv6 关闭状态 |
| `action.sh`     | action(>) 菜单：音量键即时开关 / 查状态，支持命令行参数 |
| `customize.sh`  | 安装脚本（`SKIPUNZIP=1`） |
| `toggle`        | 状态文件：`1` = 禁用 IPv6（默认），`0` = 启用 IPv6 |

---

## 默认状态

- **IPv6 关闭（OFF，禁用）**。
- `toggle` 默认值为 `1`。

---

## 使用说明

### 开启 / 关闭（手动，命令行）

```sh
# 关闭 IPv6
action.sh 1        # 或 disable / off

# 开启 IPv6
action.sh 2        # 或 enable / on

# 查看状态
action.sh 3        # 或 status
```

### 使用 Magisk / KernelSU 的 action（>）按钮

1. 在模块管理器中点击模块的 **>** 按钮。
2. 屏幕上会显示当前 IPv6 状态。
3. **音量上（+）= 启用 IPv6**，**音量下（-）= 禁用 IPv6**。
4. 等待按键识别完成即可。

### 通过 toggle 文件即时切换（无需重启）

```sh
# 禁用 IPv6
echo 1 > /data/adb/modules/global_ipv6_off/toggle

# 启用 IPv6
echo 0 > /data/adb/modules/global_ipv6_off/toggle
```

守护进程每 2 秒读取一次 toggle，会自动响应，无需重启。

---

## 工作目录备查

- 当前设备模块目录：`/data/adb/modules/global_ipv6_off/`
- 守护进程日志：`/data/local/tmp/ipv6_guard.log`（上限 256KB，自动滚动）

---

## 注意

- 仅在有 root（Magisk / KernelSU）的设备上有效，请配合对应管理软件安装。
- 某些区域网络若强制依赖 IPv6，可能会影响部分服务访问，可随时通过 toggle 重新启用。

---

> 本模块由 Operit AI 辅助完成。
