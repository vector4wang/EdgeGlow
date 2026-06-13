# EdgeGlow 代码审查报告

> 审查日期：2026-06-13
> 审查维度：简洁性 | 正确性 | 架构规范

---

## 🔴 HIGH 级别问题（必须修复）

### H1. `pulse()` 没有实际效果，等同于 `hide()`

**文件**: `GlowWindow.swift:250-252`
**维度**: 正确性

```swift
func pulse() {
    hide()
}
```

`/pulse` 在语义上应该是"短暂闪亮后恢复"，但当前实现与 `/stop` 完全相同。`PostToolUse` 和 `Stop` 触发后视觉效果无区别。

**建议**: 实现真正的脉冲效果：
```swift
func pulse() {
    // 短暂闪亮 (opacity 1.0 → 1.3 → 1.0)
    let flash = CABasicAnimation(keyPath: "opacity")
    flash.fromValue = ringLayer.opacity
    flash.toValue = min(ringLayer.opacity * 1.3, 1.0)
    flash.duration = 0.2
    flash.autoreverses = true
    ringLayer.add(flash, forKey: "pulse-flash")
    // 不隐藏，保持显示状态
}
```

---

### H2. `httpPort` 的 `didSet` 递归陷阱

**文件**: `AppSettings.swift:49-56`
**维度**: 正确性

```swift
@Published var httpPort: Int {
    didSet {
        let clamped = min(max(httpPort, 1024), 65535)
        if clamped != httpPort { httpPort = clamped; return } // 重入 didSet
        defaults.set(httpPort, forKey: Key.httpPort.rawValue)
        if httpPort != oldValue { onPortChanged?(httpPort) }
    }
}
```

用户输入 80 → clamped 变为 1024 → 重入 didSet → 此时 oldValue 已经是 clamped 值 → `onPortChanged` **不会触发** → 服务器不重启。

**建议**: 使用 `willSet` 做 clamp，或用私有存储 + 公开计算属性。

---

### H3. TextField 每次按键都重启服务器

**文件**: `SettingsView.swift:68-71` + `main.swift:28-33`
**维度**: 正确性

端口输入框直接绑定 `$settings.httpPort`，用户输入 "9876" 会触发 4 次 `didSet` → 4 次 `server.stop()` + `startServer()`。

**建议**: 使用 `@State` 本地变量，在 `.onSubmit` 或失去焦点时才提交到 `AppSettings`。

---

### H4. NWConnection 跨队列 send

**文件**: `ControlServer.swift:87-88, 121-139`
**维度**: 正确性

连接在 `.global()` 队列上 `start()`，但 `conn.send()` 在 `DispatchQueue.main` 上调用。Apple Network 框架文档要求在同一队列上操作。可能导致静默丢包或崩溃。

**建议**: 将 `conn.send()` 派发到连接的原始队列，或在 `.main` 上启动连接。

---

### H5. 60s 安全定时器 `/pulse` 不重置

**文件**: `ControlServer.swift:144-157`
**维度**: 正确性

安全定时器仅被 `/start` 重置，不被 `/pulse` 重置。如果 Agent 执行单个工具超过 60s（`PreToolUse→/start` → 执行 60s+ → `PostToolUse→/pulse`），安全定时器触发会杀死流光。

**建议**: 在 `/pulse` 处理中也调用 `resetSafetyTimer()`。

---

### H6. HTTP 状态文本始终为 "OK"

**文件**: `ControlServer.swift:86`
**维度**: 正确性

```swift
let resp = "HTTP/1.1 \(code) OK\r\n..."
```

404 和 405 响应也说 "OK"，技术上不符合 HTTP 协议。

**建议**:
```swift
let statusText = code == 200 ? "OK" : code == 404 ? "Not Found" : "Method Not Allowed"
```

---

## 🟡 MEDIUM 级别问题（建议修复）

### M1. 6 处相同的 debounce 模式

**文件**: `GlowWindow.swift:108-124`
**维度**: 简洁性

每个 `@Published` 属性触发完全相同的 `scheduleRebuild` 闭包，防抖模式复制了 6 次。

**建议**: 使用 `Publishers.Merge5` 合并为单一 publisher。

---

### M2. HooksInstaller 对话框代码重复

**文件**: `HooksInstaller.swift:31-44, 67-80`
**维度**: 简洁性

`showClaudeCodePrompt` 和 `showHermesPrompt` 几乎完全相同。

**建议**: 提取 `showPromptDialog(title:message:prompt:)` 通用方法。

---

### M3. 图层配置使用魔术数字元组

**文件**: `GlowWindow.swift:147-152`
**维度**: 简洁性

```swift
let configs: [(CGFloat, CGFloat, Double, CGFloat, CGFloat)] = [
    (1.5/2, 0.15, 12.0, 0.20, 0.45),  // 5 个无解释的数字
    ...
]
```

**建议**: 使用命名结构体 `LayerConfig`。

---

### M4. `buildLayers` 应为 private

**文件**: `GlowWindow.swift:134`
**维度**: 架构规范

`buildLayers` 仅在内部调用，不应暴露为 public。

---

### M5. `pulseTimer` 声明但从未赋值

**文件**: `ControlServer.swift:13`
**维度**: 正确性

多处取消 `pulseTimer`，但从未赋过非 nil 值。死代码。

---

### M6. `fatalError("No screen")` 在显示器休眠时崩溃

**文件**: `GlowWindow.swift:37`
**维度**: 正确性

显示器休眠或某些 VM 环境下 `NSScreen.screens` 可能为空，触发硬崩溃。

**建议**: 降级为隐藏流光 + 等待屏幕变化通知重试。

---

### M7. fade 动画代码重复

**文件**: `GlowWindow.swift:238-244, 258-265`
**维度**: 简洁性

`show()` 和 `hide()` 构建几乎相同的 `CABasicAnimation`。

**建议**: 提取 `fadeAnimation(from:to:key:)` 辅助方法。

---

### M8. 端口冲突时静默失败

**文件**: `ControlServer.swift:36-41`
**维度**: 正确性

端口被占用时，`NWListener` init 抛异常，仅 log 到 stderr。`server` 已赋值但 `listener == nil`，HTTP hooks 静默失效。

**建议**: 通过菜单栏图标或通知告知用户端口冲突。

---

### M9. 无协议抽象，无法测试

**文件**: 所有文件
**维度**: 架构规范

`GlowWindow`、`ControlServer`、`AppSettings` 都是具体类，无协议接口。项目**零测试文件**。

**建议**: 提取 `GlowControlling`、`ServerProtocol` 等协议，支持依赖注入和 mock 测试。

---

### M10. `setupStatusBar()` 60 行过长

**文件**: `main.swift:54-113`
**维度**: 简洁性

菜单项创建模式完全相同，应提取 `menuItem(_:action:symbol:)` 辅助方法。

---

## 📊 审查统计

| 严重度 | 数量 | 分布 |
|--------|------|------|
| 🔴 HIGH | 6 | GlowWindow(2), ControlServer(3), AppSettings(1) |
| 🟡 MEDIUM | 10 | GlowWindow(4), ControlServer(3), main.swift(2), HooksInstaller(1) |

| 维度 | HIGH | MEDIUM |
|------|------|--------|
| 正确性 | 5 | 4 |
| 简洁性 | 0 | 4 |
| 架构规范 | 0 | 2 |

---

## 优先级建议

### 立即修复（影响功能）
1. **H2** `didSet` 递归 → 端口变更不生效
2. **H3** TextField 按键重启 → 输入体验极差
3. **H4** 跨队列 send → 潜在崩溃
4. **H5** 安全定时器不重置 → 长任务流光误灭

### 近期修复（影响正确性）
5. **H1** pulse 效果缺失
6. **H6** HTTP 状态文本
7. **M6** fatalError 崩溃
8. **M8** 端口冲突无提示

### 持续改进（代码质量）
9. **M1-M3, M7, M10** 重复代码提取
10. **M4-M5, M9** 架构优化
