# EdgeGlow 架构分析报告

> 分析日期：2026-06-13
> 项目：claude-edge-glow-swift (EdgeGlow)
> 技术栈：Swift 5.9+ / macOS 12.0+ / 纯 Apple 框架 / 无第三方依赖

---

## 1. 系统架构图

```mermaid
graph TB
    subgraph "AI Agent 层"
        CC[Claude Code]
        HA[Hermes Agent]
    end

    subgraph "HTTP 通信层"
        CS[ControlServer<br/>NWListener :9876<br/>127.0.0.1 only<br/>GET only]
    end

    subgraph "应用核心层"
        AD[AppDelegate<br/>main.swift]
        GW[GlowWindow<br/>四层光效渲染]
        AS[AppSettings<br/>UserDefaults + Combine]
    end

    subgraph "UI 层"
        SV[SettingsView<br/>SwiftUI]
        HI[HooksInstaller<br/>配置引导]
        CT[ColorTheme<br/>4 预设 + 自定义]
    end

    subgraph "系统层"
        NW[NSScreen<br/>多显示器]
        SB[Status Bar<br/>菜单栏]
        SM[SMAppService<br/>开机自启]
    end

    CC -->|"curl /start /pulse /stop"| CS
    HA -->|"curl /start /pulse /stop"| CS
    CS -->|"onStart/onStop/onPulse"| AD
    AD -->|"show/hide/pulse"| GW
    AS -->|"$speed.$width.$theme..."| GW
    AS -->|"@Published"| SV
    AD -->|"open"| SV
    SV -->|"修改设置"| AS
    AD -->|"showConfig"| HI
    AS -->|"themeName"| CT
    GW -->|"屏幕区域"| NW
    AD -->|"menu"| SB
    AS -->|"autoStart"| SM

    style CC fill:#4a9eff,color:#fff
    style HA fill:#4a9eff,color:#fff
    style CS fill:#ff6b6b,color:#fff
    style GW fill:#51cf66,color:#fff
    style AS fill:#ffd43b,color:#000
```

---

## 2. 数据流图

```mermaid
sequenceDiagram
    participant Agent as AI Agent
    participant Server as ControlServer
    participant App as AppDelegate
    participant Glow as GlowWindow
    participant Settings as AppSettings

    Note over Agent,Settings: 流光触发流程
    Agent->>Server: GET /start
    Server->>Server: activeCount++
    Server->>App: onStart callback
    App->>Glow: show()
    Glow->>Glow: rebuildLayers() + Timer.start()
    Glow->>Glow: opacity 0→1 (1.5s fade-in)

    Agent->>Server: GET /pulse
    Server->>Server: activeCount--
    alt activeCount == 0
        Server->>App: onPulse callback
        App->>Glow: pulse() → hide()
        Glow->>Glow: opacity→0 (1.5s fade-out)
    end

    Agent->>Server: GET /stop
    Server->>Server: activeCount--
    alt activeCount == 0
        Server->>App: onStop callback
        App->>Glow: hide()
        Glow->>Glow: opacity→0 (1.5s fade-out)
    end

    Note over Agent,Settings: 设置变更流程
    Settings->>Settings: 用户修改 speed/width/theme
    Settings->>Settings: @Published 触发
    Settings->>Settings: UserDefaults.set() 持久化
    Settings-->>Glow: Combine sink (debounced 0.1s)
    Glow->>Glow: rebuildSublayers()
    Glow->>Glow: 60fps Timer 继续 tickFlow()
```

---

## 3. 四层光效渲染架构

```mermaid
graph LR
    subgraph "ringLayer (CALayer)"
        L0["Layer 0<br/>大光晕<br/>blur=12px<br/>α=0.15<br/>width=1.5×"]
        L1["Layer 1<br/>中光晕<br/>blur=8px<br/>α=0.30<br/>width=0.8×"]
        L2["Layer 2<br/>主色线<br/>blur=2px<br/>α=0.70<br/>width=0.3×"]
        L3["Layer 3<br/>亮芯<br/>blur=0px<br/>α=0.95<br/>width=0.1×"]
    end

    Timer["Timer 60fps<br/>lineDashPhase"] --> L0
    Timer --> L1
    Timer --> L2
    Timer --> L3

    KF["CAKeyframeAnimation<br/>strokeColor 循环"] --> L0
    KF --> L1
    KF --> L2
    KF --> L3

    style L0 fill:#ff6b6b,color:#fff
    style L1 fill:#ff922b,color:#fff
    style L2 fill:#fcc419,color:#000
    style L3 fill:#fff,color:#000
```

---

## 4. 组件依赖关系

```mermaid
graph TD
    main["main.swift<br/>入口 + AppDelegate"]
    GlowWindow["GlowWindow.swift<br/>~400 行<br/>核心渲染引擎"]
    ControlServer["ControlServer.swift<br/>HTTP 服务器"]
    AppSettings["AppSettings.swift<br/>设置持久化"]
    SettingsView["SettingsView.swift<br/>SwiftUI 设置 UI"]
    ColorTheme["ColorTheme.swift<br/>颜色主题"]
    HooksInstaller["HooksInstaller.swift<br/>配置引导"]
    L10n["L10n.swift<br/>国际化"]

    main --> GlowWindow
    main --> ControlServer
    main --> AppSettings
    main --> SettingsView
    main --> HooksInstaller
    GlowWindow --> AppSettings
    GlowWindow --> ColorTheme
    SettingsView --> AppSettings
    SettingsView --> ColorTheme
    SettingsView --> HooksInstaller
    AppSettings --> ColorTheme
    HooksInstaller --> AppSettings
    main --> L10n
    SettingsView --> L10n
    GlowWindow --> L10n

    style main fill:#845ef7,color:#fff
    style GlowWindow fill:#51cf66,color:#fff
    style ControlServer fill:#ff6b6b,color:#fff
    style AppSettings fill:#ffd43b,color:#000
```

---

## 5. 项目规模统计

| 文件 | 行数 | 职责 |
|------|------|------|
| GlowWindow.swift | ~400 | 核心渲染引擎（四层光效 + 动画 + 状态机） |
| ControlServer.swift | ~200 | HTTP 服务器（NWListener + 路由） |
| AppSettings.swift | ~200 | 设置管理（UserDefaults + Combine） |
| SettingsView.swift | ~250 | SwiftUI 设置界面 |
| main.swift | ~150 | 入口 + AppDelegate + 菜单栏 |
| HooksInstaller.swift | ~150 | Agent 配置引导 |
| ColorTheme.swift | ~100 | 颜色主题定义 |
| L10n.swift | ~80 | 中英双语国际化 |
| **合计** | **~1530** | **8 个源文件，零第三方依赖** |

---

## 6. 设计亮点

### 6.1 零依赖架构
- 纯 Swift + Apple 原生框架（Cocoa + Network + Combine + SwiftUI）
- 无 Package.swift 依赖，构建简单，编译快速

### 6.2 四层光效叠加
- 从外到内：模糊→锐利，暗淡→明亮
- 模拟真实霓虹灯的 bloom 效果
- 每层独立动画，产生深度感

### 6.3 引用计数防误灭
- ControlServer 的 `activeCount` 机制
- 多个 Agent 窗口同时工作时，只有全部停止才灭光
- 60s 安全定时器防止 Agent 崩溃后流光卡住

### 6.4 响应式设置传播
- AppSettings @Published → Combine sink → GlowWindow 自动重建
- 0.1s 防抖避免滑动条快速拖动时频繁重建
- 设置变更无需手动通知，数据流单向清晰

### 6.5 安全设计
- `acceptLocalOnly` 仅接受本地连接
- 仅 GET 方法，无请求体解析
- 无 CORS（OPTIONS 除外），网页 JS 无法调用
- 无数据收集，无遥测

---

## 7. 已识别问题

### 7.1 Bug 级别

| 问题 | 严重度 | 说明 |
|------|--------|------|
| `pulse()` 等同于 `hide()` | 中 | `/pulse` 应该产生"脉冲"效果（短暂闪亮），但当前只是淡出。PostToolUse 和 Stop 视觉效果完全相同 |
| `show()` 中 opacity 设置顺序 | 低 | 先设 model opacity=1.0 再添加从 0→1 的动画，如果 hide() 在 fade-in 期间被调用，读 model 层会得到错误值（但 presentation 层是正确的） |
| 隐藏状态下设置变更仍重建图层 | 低 | 不可见时 rebuildSublayers() 仍会销毁重建所有 CAShapeLayer，浪费 GPU 资源 |

### 7.2 性能优化建议

| 建议 | 影响 | 难度 |
|------|------|------|
| CIGaussianBlur 在 Retina 全屏下开销大 | 高 | 中 — 可考虑预渲染到位图或用多层透明度模拟 |
| 60fps Timer 持续运行即使静态 | 中 | 低 — 可在完全显示后降频到 30fps 或暂停 |
| `animationDuration * 3` 硬编码 | 低 | 低 — 可拆为独立设置项 |
| inset=2 硬编码出现在 3 处 | 低 | 低 — 提取为命名常量 |

### 7.3 功能增强建议

| 建议 | 说明 |
|------|------|
| 真正的 pulse 效果 | `/pulse` 时短暂闪亮（opacity 1.2× → 1.0）再恢复，而非直接 hide |
| 新 Agent 平台支持 | Cursor、Codex CLI、Windsurf 等也支持 hooks |
| 状态指示增强 | 除流光外，可考虑菜单栏图标也反映 AI 状态 |
| 多语言扩展 | L10n 硬编码字典方式不适合大规模扩展，可迁移到 .strings 文件 |
| 快捷键 | 为手动开/关、切换主题等添加全局快捷键 |

---

## 8. 安全审计

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 网络暴露 | ✅ 安全 | 仅绑定 127.0.0.1，acceptLocalOnly |
| 请求验证 | ✅ 安全 | 仅接受 GET，拒绝 POST/PUT/DELETE |
| 输入解析 | ✅ 安全 | 只解析请求行，无 body 解析 |
| CORS | ⚠️ 注意 | OPTIONS 返回 `Access-Control-Allow-Origin: *`，但 GET 响应无 CORS 头 |
| 数据收集 | ✅ 安全 | 无遥测，无外部请求 |
| 权限要求 | ⚠️ 注意 | 需要屏幕录制权限（部分 macOS 版本） |
| 端口安全 | ✅ 安全 | 默认 9876，可配置，仅本地 |

---

## 9. 总结

EdgeGlow 是一个**架构清晰、实现精简**的 macOS 工具：

- **8 个源文件，~1530 行代码，零依赖**
- 核心渲染引擎（GlowWindow）是项目灵魂，四层光效 + 60fps 动画实现逼真霓虹效果
- HTTP 通信层简洁安全，引用计数设计合理
- 设置系统基于 Combine 响应式传播，数据流清晰
- 主要改进空间：pulse 效果、性能优化、更多 Agent 平台支持
