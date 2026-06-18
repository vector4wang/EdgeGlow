# Dev.to 技术文章

## 文章标题
```
Why Your AI Coding Agent Needs Visual Feedback (and how I built EdgeGlow)
```

## 备选标题
```
Building a Neon Glow Effect in SwiftUI: Lessons from Core Animation
How I Added Visual Feedback to My AI Coding Workflow with 892KB
```

---

## 正文

If you use Claude Code or similar AI coding agents, you know the pain: the AI is working in the terminal, but you can't tell if it's still thinking or waiting for your input. You keep alt-tabbing, breaking your flow.

I built **EdgeGlow** to solve this. It's a free, open-source macOS menu bar app that puts a colorful glow around your screen when the AI is working.

In this post, I'll walk through the technical challenges I faced and how I solved them.

---

## How It Works

```
AI Agent triggers hook → curl http://127.0.0.1:9876/start → Screen glows
AI Agent finishes     → curl http://127.0.0.1:9876/stop  → Glow fades out
```

That's it. Dead simple.

The interesting part is the animation. Let me walk you through it.

---

## The Technical Challenge

I needed a smooth marquee effect around the screen edges — essentially a dashed line that flows continuously.

### Why Not CABasicAnimation?

My first approach used `CABasicAnimation` on `lineDashPhase`:

```swift
let anim = CABasicAnimation(keyPath: "lineDashPhase")
anim.fromValue = 0
anim.toValue = perimeter
anim.duration = 5.0
anim.repeatCount = .infinity
shape.add(anim, forKey: "flow")
```

This worked... until the window was hidden and shown again.

Core Animation would lose the animation state, and the marquee would:
- **Freeze** in place
- **Reverse direction** suddenly
- **Jump** to a random position

### The Root Cause

`CABasicAnimation` relies on Core Animation's animation system, which is tied to the layer's presentation state. When the window is hidden (`orderOut`) or the layer is removed from the hierarchy, the animation state is lost.

I tried several workarounds:
1. **Pause/resume animations** — didn't work reliably
2. **Keep the window alive** — wasted resources
3. **Reset animation on show** — caused visual jumps

None of them were bulletproof.

### The Solution: Timer-Driven Animation

I switched to a `Timer` at 60fps that directly updates `lineDashPhase`:

```swift
private var flowTimer: Timer?
private var dashPhase: CGFloat = 0
private var lastTickTime: CFTimeInterval = 0

private func startFlow() {
    stopFlow()
    lastTickTime = CACurrentMediaTime()
    
    flowTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
        self?.tickFlow()
    }
    RunLoop.main.add(flowTimer!, forMode: .common)
}

private func tickFlow() {
    let now = CACurrentMediaTime()
    let dt = CGFloat(now - lastTickTime)
    lastTickTime = now
    
    // Clamp dt to prevent huge jumps (e.g., returning from background)
    let clampedDt = min(dt, 0.1)
    
    let perimeter = currentPerimeter()
    guard perimeter > 0, settings.animationDuration > 0 else { return }
    
    let speed = perimeter / CGFloat(settings.animationDuration)
    dashPhase += speed * clampedDt * (settings.clockwise ? 1 : -1)
    
    ringLayer.sublayers?.forEach { layer in
        (layer as? CAShapeLayer)?.lineDashPhase = dashPhase
    }
}
```

This is **bulletproof** — no dependency on Core Animation's animation system, no state loss on window visibility changes.

The performance is also great: updating a single `CGFloat` property at 60fps uses ~0% CPU.

---

## The 4-Layer + 20-Segment Glow Effect

To create a realistic neon glow, I stack 4 `CAShapeLayer` instances. But the real magic is the **iridescent theme** (default): the screen edge is split into 20 segments, each with a different hue (purple → blue → cyan → pink → orange → gold), mimicking iPhone's Apple Intelligence Siri edge glow. The colors cycle continuously with staggered time offsets, and Gaussian blur at segment boundaries creates smooth transitions.

### Layer Configuration

```swift
let configs: [(widthMul: CGFloat, alphaMul: CGFloat, blur: Double)] = [
    (baseWidth * 1.5, 0.15, 12.0),  // Layer 1: Wide line, high blur, low alpha → outer glow
    (baseWidth * 0.8, 0.30, 8.0),   // Layer 2: Medium line, medium blur, medium alpha → mid glow
    (baseWidth * 0.3, 0.70, 2.0),   // Layer 3: Thin line, low blur, high alpha → core line
    (baseWidth * 0.1, 0.95, 0.0),   // Layer 4: Thinnest line, no blur, full alpha → bright center
]
```

### Building Each Layer

```swift
for (lineWidth, alpha, blur) in configs {
    let shape = CAShapeLayer()
    shape.frame = ringLayer.bounds
    shape.path = path
    shape.fillColor = nil
    shape.strokeColor = color.withAlphaComponent(alpha).cgColor
    shape.lineWidth = lineWidth
    shape.lineCap = .round
    shape.lineDashPattern = [NSNumber(value: Double(dashLen)),
                             NSNumber(value: Double(gapLen))]
    
    if blur > 0 {
        let bf = CIFilter(name: "CIGaussianBlur")!
        bf.setValue(blur, forKey: "inputRadius")
        shape.filters = [bf]
    }
    
    ringLayer.addSublayer(shape)
}
```

### The Result

The 4 layers stack on top of each other, creating a realistic neon light tube effect:

```
Layer 4: ██ (bright center, no blur)
Layer 3: ████ (core line, blur 2)
Layer 2: ██████ (mid glow, blur 8)
Layer 1: ████████ (outer glow, blur 12)
```

The outer layers create the soft glow halo, while the inner layers create the bright core. Together, they look like a real neon light.

---

## Multi-Terminal Reference Counting

### The Problem

If you have multiple Claude Code terminals running, one calling `/stop` would kill the glow even though others are still active.

### The Solution: Reference Counting

```swift
class ControlServer {
    private var activeCount = 0
    
    private func processRequest(_ raw: String, conn: NWConnection) {
        switch path {
        case "/start":
            activeCount += 1
            onStart?()
            resetSafetyTimer()
            
        case "/stop":
            activeCount = max(0, activeCount - 1)
            if activeCount == 0 { onStop?() }
            
        case "/pulse":
            activeCount = max(0, activeCount - 1)
            if activeCount == 0 { onPulse?() }
        }
    }
}
```

Now `/start` increments the count, `/stop` decrements it. The glow only hides when the count reaches 0.

### Safety Timeout

What if an agent crashes without sending `/stop`? The reference count would stay > 0 forever.

Solution: a 120-second safety timeout:

```swift
private func resetSafetyTimer() {
    safetyTimer?.cancel()
    let work = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        if self.activeCount > 0 {
            print("⏰ 60s no activity, resetting to 0")
            self.activeCount = 0
            self.onStop?()
        }
    }
    safetyTimer = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 60.0, execute: work)
}
```

Every `/start` resets the timer. If no `/start` is received for 60 seconds, the count resets to 0.

---

## Security Considerations

EdgeGlow runs an HTTP server on `127.0.0.1:9876`. I had to be careful about security:

### Localhost Only

```swift
let param = NWParameters.tcp
param.acceptLocalOnly = true  // Only accept connections from localhost
```

This prevents external network access.

### GET Requests Only

```swift
guard method == "GET" || method == "OPTIONS" else {
    sendResponse(405, "Method Not Allowed", conn: conn)
    return
}
```

Rejects POST/PUT/DELETE to prevent CSRF attacks.

### No CORS Headers

```swift
// No Access-Control-Allow-Origin header
// Web JavaScript cannot invoke endpoints
```

This prevents web pages from calling the API via JavaScript.

### No Data Collection

- No analytics
- No telemetry
- No network requests (except localhost)

---

## Multi-Monitor Support

### The Challenge

How to handle multiple displays with different sizes?

### The Solution

Calculate the union of all screen frames:

```swift
func totalScreenFrame() -> NSRect {
    var frame = NSRect.zero
    for screen in NSScreen.screens {
        frame = NSUnionRect(frame, screen.frame)
    }
    return frame
}
```

### Handling Display Changes

Listen to screen parameter changes:

```swift
NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    // Debounce 500ms to avoid rapid rebuilds
    self?.screenChangeWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
        self?.handleScreenChange()
    }
    self?.screenChangeWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
}
```

When displays change, rebuild the layers with the new frame size.

---

## Settings Persistence

### The Challenge

How to make settings reactive and persist them across launches?

### The Solution

Use `ObservableObject` + `UserDefaults` + Combine:

```swift
class AppSettings: ObservableObject {
    @Published var speed: Int {
        didSet {
            UserDefaults.standard.set(speed, forKey: "speed")
            notifyChange()
        }
    }
    
    static let shared = AppSettings()
    
    private init() {
        self.speed = UserDefaults.standard.integer(forKey: "speed")
        if speed == 0 { speed = 5 } // default
    }
}
```

Then in GlowWindow, observe changes:

```swift
settings.$speed.sink { [weak self] _ in
    self?.rebuildLayers()
}.store(in: &cancellables)
```

When the user changes the speed slider, the layers rebuild automatically.

---

## Performance

| Metric | Value | Notes |
|--------|-------|-------|
| CPU | ~0% | Timer 60fps only updates one CGFloat |
| Memory | ~50MB | 4 CAShapeLayer + CIFilter |
| Disk | 892KB | Universal Binary (arm64 + x86_64) |
| Network | 0 | localhost only, no external requests |

The key insight: updating a property at 60fps is cheap. It's the GPU-accelerated CAShapeLayer rendering that does the heavy lifting.

---

## Try It

- **GitHub**: https://github.com/vector4wang/EdgeGlow
- **Download**: https://github.com/vector4wang/EdgeGlow/releases
- **Size**: 892KB zipped
- **License**: MIT
- **macOS**: 13.0+ (Ventura)

It's my first macOS app. Built with pure Swift + SwiftUI, no third-party dependencies.

Would love to hear your feedback!

---

## Tags

```
#swift #swiftui #macos #coreanimation #opensource #claudecode #ai
```

---

## Dev.to 发布策略

### 目标指标
- **Reactions**: 50+ (❤️🦄🤯 等表情)
- **Comments**: 10+ 条技术讨论

### 时间选择
- **最佳时间**: 周二/周三/周四 2:00-4:00 PM UTC
- **避免**: 周末

### 互动要点
1. **发布后**: 分享到 Twitter/LinkedIn 增加曝光
2. **评论区**: 详细回答技术问题
3. **Series**: 可以写成系列文章（Core Animation 深入、SwiftUI 最佳实践等）

### Dev.to 用户偏好
- ✅ 代码片段 + 解释
- ✅ 真实问题 + 解决方案
- ✅ 性能数据
- ✅ 开源项目
- ❌ 纯营销内容
- ❌ 没有代码的文章

---

## 预期用户爽点

1. **技术深度**: Timer vs CABasicAnimation 的权衡
2. **代码质量**: 干净的 Swift 代码，可直接复用
3. **性能数据**: ~0% CPU、892KB
4. **安全意识**: localhost only、GET-only、no CORS
5. **实用价值**: 解决 AI 编程的实际痛点
