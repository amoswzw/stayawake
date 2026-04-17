# stayawake

macOS 菜单栏工具。自动判断长任务、媒体播放、全屏活动、前台工作应用等信号，并用系统电源断言控制“是否允许系统空闲休眠”。

当前实现目标：**小工具、低资源、功能完整、不过度工程化**。

## 当前状态

- Swift Package 可执行目标：`Sources/stayawake`
- macOS 最低版本：13.0
- Swift tools：5.9
- UI：AppKit `NSStatusItem` 菜单栏容器 + SwiftUI 设置/日志窗口
- 打包脚本：`build-app.sh`
- app bundle：`LSUIElement = true`，不显示 Dock 图标
- 开源基础文件：`README.md`、`LICENSE`、`.gitignore`

## 核心不变量

- 默认偏向 keep awake：不误杀长任务优先，假阳性比假阴性更可接受。
- 低资源占用优先：自动模式不做高频轮询，不引入后台 helper、XPC、daemon 或第三方依赖。
- 不读取用户内容：只读聚合系统信号和 bundle/process 名称，不读文档、窗口文本、终端输出、浏览器内容。
- 不上传数据：无网络服务、无账号、无遥测。
- 功能保持小而完整：新增大功能前先确认，不为了架构对称增加复杂层。

## 与 macOS 系统功能的关系

stayawake 与 macOS 自带功能有部分重叠，但不直接冲突。

- 重叠点：
  - macOS 已有“锁定屏幕时关闭显示器”“防止自动睡眠”“低电量模式”等电源设置。
  - macOS 也有系统级 power assertions，很多播放器、下载器、构建工具会自己创建断言。
- stayawake 的差异：
  - 不修改系统设置，不替用户永久改变 Energy/Battery 偏好。
  - 只在当前 app 判断需要时创建 `kIOPMAssertionTypePreventUserIdleSystemSleep`。
  - 断言释放后，macOS 原本的休眠策略继续生效。
  - 它是自动策略聚合器：把 CPU、网络、磁盘、音频、全屏、前台 app、进程名、idle、电池、热状态合并成一个决策。
- 不冲突的原因：
  - 使用 Apple 官方 IOKit power assertion API。
  - 不阻止用户手动睡眠、关机、重启。
  - 不修改 pmset、不改系统电源配置。
  - 使用的是 `PreventUserIdleSystemSleep`，主要阻止“用户空闲导致的系统睡眠”，不是强行阻止所有睡眠路径。
- 需要注意：
  - 当 stayawake 持有断言时，macOS 可能不会按原计划空闲睡眠，这是本工具的核心功能，不是 bug。
  - 在电池供电且 thermal state 为 serious/critical 时，策略会允许休眠以保护设备。
  - 显示器睡眠和系统睡眠不是一回事；当前断言目标是系统空闲睡眠。

## 主要功能

- 菜单栏状态图标：
  - Sleep：睡觉小人
  - Awake：举闪电小人
  - `NSImage.isTemplate = true`，自动适配深色/浅色菜单栏
- 菜单打开后直接显示：
  - 当前状态
  - 当前原因
  - 下次检查时间
  - 最近 5 条 log
  - 手动保持唤醒操作
  - 设置、日志窗口、退出
- 设置窗口：
  - 顶部图标与菜单栏同源，并跟随当前 awake/sleep 状态切换
  - 启动项、语言、idle、采样、cooldown、CPU/网络/磁盘阈值
  - 任务进程列表、工作 app 白名单、blocklist
- 日志窗口：
  - 默认 680x660
  - 最近 5 条摘要 + 详情面板
  - 状态颜色区分
- 事件日志：
  - 内存 ring buffer，默认容量 1024
  - 自动决策按 `awake/sleep + reason` 去重
  - 手动操作、启动、恢复自动、错误仍正常记录

## 电源控制

`PowerAssertionManager` 是单例幂等封装。

- 创建断言：`IOPMAssertionCreateWithName`
- 类型：`kIOPMAssertionTypePreventUserIdleSystemSleep`
- 级别：`kIOPMAssertionLevelOn`
- `ensureAwake(reason:)`：
  - 已持有断言时只更新 reason，不创建新断言
  - 未持有时创建断言
- `release()`：
  - 未持有时 no-op
  - 持有时释放 `IOPMAssertionID`

不要改成 shell `caffeinate`。当前实现更可控，也更适合菜单栏 app。

## 调度策略

当前不是固定每 15 秒完整采样。

- `sampleIntervalSeconds` 默认 15 秒，但只是兜底。
- 自动模式下，每次 `keepAwake` / `allowSleep` 决策后，会设置 `nextAutomaticCheckAt = now + cooldownSeconds`。
- `cooldownSeconds` 默认 120 秒，所以自动模式通常约 120 秒后重新完整采样。
- 手动 timed override：timer 直接等到到期点附近。
- 手动 until off：固定 300 秒 tick，避免无意义的 15 秒轮询。
- timer 使用 tolerance：`min(10, max(1, interval * 0.2))`。

这个设计是刻意的：优先低资源占用，而不是秒级响应。

## 检测信号

采集入口：`SignalCollector.sample(taskProcessNames:)`

| 信号 | 实现 |
| --- | --- |
| idle 秒数 | `CGEventSource.secondsSinceLastEventType` |
| 前台 app | `NSWorkspace.shared.frontmostApplication` |
| 进程名匹配 | `sysctl(KERN_PROC_ALL)` |
| CPU | `host_processor_info`，每核最大使用率 |
| 网络速率 | `getifaddrs` / `if_data` |
| 磁盘速率 | `IOBlockStorageDriver` statistics |
| 音频活跃 | CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` |
| 全屏窗口 | `CGWindowListCopyWindowInfo` |
| 电池/AC | `IOPSGetProvidingPowerSourceType` |
| 热状态 | `ProcessInfo.processInfo.thermalState` |

资源类信号 CPU/网络/磁盘使用 60 秒滑动窗口，取 P75。

AudioProbe 已缓存设备列表：

- 缓存 TTL：300 秒
- 平时只检查 cached device 是否 running
- 枚举失败时优先使用已有缓存

## 策略顺序

纯函数：`Policy.decide(_:)`

1. 手动覆盖：
   - until off → keep awake
   - timed 未过期 → keep awake
2. 电池供电且 thermal serious/critical → allow sleep
3. 资源繁忙 → keep awake
4. 音频活跃 → keep awake
5. 任一 probe 失败 → keep awake
6. 最近输入 + 任务进程 → keep awake
7. 最近输入 + 前台工作 app → keep awake
8. 最近输入 + 全屏 → keep awake
9. 用户 idle → allow sleep
10. 默认 → allow sleep

`SignalDeriver` 负责把 `Context` 转为 `TaskSignal`，包括 blocklist 过滤。

## 默认配置

见 `ConfigStore.Config`。

| 配置 | 默认值 |
| --- | --- |
| sample interval | 15s 兜底 |
| idle threshold | 10 min |
| CPU threshold | 30% any core |
| network threshold | 50 KB/s |
| disk threshold | 1 MB/s |
| cooldown | 120s |
| manual until-off tick | 300s |
| log capacity | 1024 |

默认任务进程包含构建、下载、压缩、数据库 dump、AI agent CLI 等常见长任务进程。

默认工作 app 包含 Xcode、VS Code、Cursor、JetBrains、Terminal、iTerm2、Warp、Adobe、Final Cut、DaVinci Resolve、Figma 等。

## 权限边界

不要引导用户开启 Accessibility。

当前 API 都不需要 Accessibility：

- idle：`CGEventSource`
- 前台 app：`NSWorkspace`
- 窗口列表：`CGWindowListCopyWindowInfo`
- power assertion：IOKit
- launch at login：`SMAppService.mainApp`

如果未来引入需要 Accessibility 的功能，必须先确认它确实是核心功能。

## UI 与资源

应用资源在 `Sources/stayawake/Resources`。

- `status-awake-template.png`
- `status-sleep-template.png`
- `stayawake.icns`
- `stayawake-app-icon.png`
- `en.lproj/Localizable.strings`
- `zh-Hans.lproj/Localizable.strings`

菜单栏图标优先加载 PNG 模板资源；资源缺失时回退到代码绘制的 NSBezierPath 图标。

文案必须走本地化资源。当前支持：

- English
- Simplified Chinese

## 项目结构

```text
.
├── Package.swift
├── build-app.sh
├── README.md
├── LICENSE
├── .gitignore
├── Sources/stayawake
│   ├── App.swift
│   ├── AppCoordinator.swift
│   ├── MenuBarController.swift
│   ├── SettingsView.swift
│   ├── LogsView.swift
│   ├── Policy.swift
│   ├── *Probe.swift
│   └── Resources
└── Tests/stayawakeTests
    ├── PolicyTests.swift
    └── EventLogTests.swift
```

发布 GitHub 前不要提交：

- `.build/`
- `build/`
- `.swiftpm/`
- Xcode user state

这些已写入 `.gitignore`。

## 测试要求

每次改策略、日志、调度、配置或信号派生，都跑：

```bash
swift test
```

当前测试覆盖：

- `Policy.decide` 主要分支
- `SignalDeriver` 进程匹配、recent input、blocklist
- `SlidingWindow` P75 与 eviction
- `EventLog` 自动决策去重

打包验证：

```bash
./build-app.sh
open build/stayawake.app
```

## 开发边界

优先保留当前小型结构。

不要默认引入：

- 第三方依赖
- 数据库
- 后台 daemon / privileged helper
- XPC
- SwiftData / CoreData
- 高复杂度多级采样调度
- 网络同步或遥测

如果以后真的要优化 ProcessProbe / FullscreenProbe 降频，可以做，但当前为了保持工具简单，暂不实现。
