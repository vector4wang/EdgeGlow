# Hacker News 发布文案

## Show HN 标题

```
Show HN: EdgeGlow – Screen glow effect for AI coding agents (macOS, Swift)
```

---

## 首条评论

Hi HN,

I built a small macOS menu bar app that renders a glowing marquee around screen edges when AI coding agents (Claude Code, Hermes Agent) are working.

### The Problem

When using Claude Code, I can't tell if the AI is still thinking or waiting for input. I keep checking, which breaks flow.

### The Solution

HTTP hooks in the agent config call a local server (127.0.0.1:9876), which triggers glow state changes:
- `/start` → flowing marquee (AI thinking)
- `/stop` → fade out (done)

### Technical Details

**Pure Swift + SwiftUI, no dependencies**

**4-layer CAShapeLayer with CIGaussianBlur for neon effect:**
```
Layer 1: Wide line, CIGaussianBlur(12), low alpha → outer glow
Layer 2: Medium line, blur(8), medium alpha → mid glow
Layer 3: Thin line, blur(2), high alpha → core line
Layer 4: Thinnest line, no blur, full alpha → bright center
```

**Timer-driven lineDashPhase animation**

My first approach used `CABasicAnimation` on `lineDashPhase`:
```swift
let anim = CABasicAnimation(keyPath: "lineDashPhase")
anim.fromValue = 0
anim.toValue = perimeter
anim.repeatCount = .infinity
shape.add(anim, forKey: "flow")
```

This worked... until the window was hidden and shown again. Core Animation would lose the animation state, and the marquee would freeze or even reverse direction.

I switched to a `Timer` at 60fps that directly updates `lineDashPhase`:
```swift
flowTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
    let speed = perimeter / animationDuration
    dashPhase += speed * dt
    ringLayer.sublayers?.forEach { layer in
        (layer as? CAShapeLayer)?.lineDashPhase = dashPhase
    }
}
```

This is bulletproof — no dependency on Core Animation's animation system, no state loss on window visibility changes.

**Reference counting for multi-terminal support**

If you have multiple Claude Code terminals running, one calling `/stop` would kill the glow even though others are still active.

Solution: reference counting. `/start` increments, `/stop` decrements. Only hide when count reaches 0. Plus a 60-second safety timeout in case an agent crashes without sending `/stop`.

**Security considerations:**
- HTTP server uses `NWListener` with `acceptLocalOnly = true`
- Only accepts GET requests (rejects POST/PUT/DELETE)
- No CORS headers (web JavaScript cannot invoke endpoints)
- Binds to 127.0.0.1 only (not accessible from network)

**Other details:**
- Universal Binary (arm64 + x86_64), ~892KB zipped
- macOS 13.0+ (Ventura)
- ~0% CPU, ~50MB RAM
- MIT License

### Links

- Source: https://github.com/vector4wang/EdgeGlow
- Download: https://github.com/vector4wang/EdgeGlow/releases

---

## 后续互动准备

### 可能的技术问题 & 回答

**Q: Why not use CABasicAnimation?**
A: Core Animation loses animation state when windows are hidden/shown. The marquee would freeze or reverse direction. Timer-driven animation bypasses this entirely.

**Q: Why 4 layers instead of one?**
A: To simulate a real neon light tube. The outer layers have wide lines + high blur for the glow halo, inner layers have thin lines + low blur for the bright core. Stacking them creates a realistic neon effect.

**Q: What about power consumption?**
A: The Timer runs at 60fps but only updates a single CGFloat property (lineDashPhase). CPU usage is effectively 0%. The 4 CAShapeLayer instances with CIFilter are GPU-accelerated.

**Q: Can it work with other AI agents?**
A: Yes, any agent that can make HTTP requests. Just configure the agent to call `http://127.0.0.1:9876/start` when it starts working and `/stop` when done.

**Q: Why not a native Claude Code plugin?**
A: Claude Code's hook system is the official integration point. It's more flexible than a plugin because it works with any agent that supports hooks or can make HTTP calls.

**Q: What happens if the agent crashes?**
A: The 60-second safety timeout automatically resets the glow. If no `/start` is received for 60 seconds, the reference count resets to 0 and the glow fades out.

---

## HN 发布策略

### 目标指标
- **Points**: 100+
- **Comments**: 20+ 条技术讨论

### 时间选择
- **最佳时间**: 周二/周三/周四 9:00-11:00 AM PT
- **避免**: 周末、美国假期

### 互动要点
1. **首条评论**: 必须在发布后立即贴出（说明背景、技术细节）
2. **回复风格**: 技术导向、简洁、不推销
3. **不要**: 要求朋友upvote、使用"awesome"、"amazing"等夸张词

### HN 用户偏好
- ✅ 技术深度（Core Animation、Timer vs CABasicAnimation）
- ✅ 真实问题（AI编程的痛点）
- ✅ 开源 + MIT
- ✅ 轻量（892KB）
- ✅ 隐私安全（仅本地、无数据收集）
- ❌ 过度营销
- ❌ 没有技术含量的产品

---

## 预期用户爽点

1. **技术实现**: Timer vs CABasicAnimation 的权衡
2. **多层光效**: 4-layer CAShapeLayer 模拟霓虹灯
3. **引用计数**: 多终端支持的设计
4. **安全意识**: acceptLocalOnly、GET-only、no CORS
5. **极简主义**: 892KB、无依赖、纯Swift
