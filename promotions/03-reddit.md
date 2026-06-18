# Reddit 发布文案

## 目标 Subreddit

1. **r/macapps** - macOS 应用推荐
2. **r/opensource** - 开源项目
3. **r/SwiftUI** - SwiftUI 开发
4. **r/LocalLLaMA** - AI/LLM 本地部署

---

## r/macapps 版本

### 标题
```
[Free & Open Source] EdgeGlow – A screen glow effect that shows when your AI coding agent is thinking
```

### 正文

Hey everyone!

I made a small macOS menu bar app called **EdgeGlow**. When Claude Code or Hermes Agent is working, colorful lights flow around your screen edges. When it's done, they fade out.

**No more guessing if your AI is still thinking.**

![EdgeGlow Effect](https://github.com/vector4wang/EdgeGlow/raw/main/images/效果界面.jpg)

### Why I Built This

I use Claude Code for programming, and I kept alt-tabbing to check if the AI was still working. It broke my flow constantly. So I made a tiny app that shows visual feedback at the screen edges.

### How It Works

1. You configure HTTP hooks in Claude Code / Hermes Agent
2. When the agent triggers events (UserPromptSubmit, PreToolUse, etc.), it calls `localhost:9876`
3. EdgeGlow shows/hides the glow accordingly

That's it. Dead simple.

### Features

![Features Interface](https://github.com/vector4wang/EdgeGlow/raw/main/images/功能界面.jpg)

- 🎨 **5 color themes** (Iridescent, Rainbow, Pastel, Fire, Ice)
- ✨ **Iridescent theme** simulates iPhone Apple Intelligence edge glow — 20-segment perimeter coloring
- 🔄 **Two glow modes**: Flow (marquee) + Breathe (opacity pulse)
- 🖥️ **Multi-monitor support** (auto-adapts to display changes)
- ⚙️ **Customizable** (speed, width, brightness, direction)
- 💨 **Ultra lightweight** (~0% CPU, ~50MB RAM, only 892KB)
- 🔒 **Privacy first** (localhost only, no data collection)
- 🌐 **Bilingual** (Chinese & English)

### Tech Stack

Pure Swift + SwiftUI, CALayer animations, NWListener for the HTTP server. No third-party dependencies.

The interesting part was the animation. I use 4 layered CAShapeLayer instances with CIGaussianBlur to create a realistic neon glow effect. The flow animation is driven by CVDisplayLink (screen-sync, not affected by RunLoop). The iridescent theme uses 20 segments around the perimeter, each with a staggered color cycle, creating a smooth gradient that mimics iPhone's Apple Intelligence Siri glow.

### Links

- **GitHub**: https://github.com/vector4wang/EdgeGlow
- **Download**: https://github.com/vector4wang/EdgeGlow/releases
- **License**: MIT
- **System**: macOS 13.0+ (Ventura), Intel & Apple Silicon

### Feedback Welcome!

This is my first macOS app. I'd love to hear your thoughts, suggestions, or bug reports. Feel free to open an issue on GitHub or comment here.

---

## r/opensource 版本

### 标题
```
[Project] EdgeGlow – Open-source macOS app that shows screen glow when AI coding agents are working
```

### 正文

Hi r/opensource!

I just released **EdgeGlow**, a free, open-source macOS menu bar app under the MIT license.

### What It Does

EdgeGlow displays a glowing marquee around your screen edges when AI coding agents (Claude Code, Hermes Agent) are working:
- 🟢 AI thinking → lights flow around the screen
- 🔴 Done → lights fade out

### Why Open Source?

I built it for my own workflow, but I think it's useful for anyone using AI coding agents. The code is clean, well-documented, and has no proprietary dependencies. Contributions welcome!

### Technical Highlights

**Pure Swift + SwiftUI, no dependencies**
- ~892KB zipped
- Universal Binary (arm64 + x86_64)
- macOS 13.0+

**Core Animation Done Right**
- 4-layer CAShapeLayer with CIGaussianBlur for neon effect
- Timer-driven `lineDashPhase` animation (more reliable than CABasicAnimation)
- GPU-accelerated, ~0% CPU usage

**Security First**
- HTTP server binds to 127.0.0.1 only (`acceptLocalOnly`)
- Only accepts GET requests
- No CORS headers
- No data collection, no telemetry

### Code Structure

```
Sources/
├── main.swift              # Entry point + AppDelegate
├── GlowWindow.swift        # Glow window + 4-layer effect + Timer animation
├── ControlServer.swift     # HTTP control server (NWListener)
├── HooksInstaller.swift    # Agent configuration prompts
├── L10n.swift              # Bilingual i18n
├── Settings/
│   ├── AppSettings.swift   # UserDefaults + Combine reactive
│   └── SettingsView.swift  # SwiftUI settings UI
└── Themes/
    └── ColorTheme.swift    # 5 color themes
```

### Links

- **GitHub**: https://github.com/vector4wang/EdgeGlow
- **License**: MIT
- **Issues**: https://github.com/vector4wang/EdgeGlow/issues

### Contributing

PRs welcome! If you have ideas for new features, themes, or improvements, feel free to contribute.

---

## r/SwiftUI 版本

### 标题
```
Built a macOS menu bar app with SwiftUI + CALayer – 4-layer neon glow effect for AI coding agents
```

### 正文

Hi r/SwiftUI!

I just finished my first macOS app using SwiftUI + CALayer, and I wanted to share the technical approach.

### The App

**EdgeGlow** shows a glowing marquee around screen edges when AI coding agents (Claude Code, Hermes Agent) are working.

### Technical Challenges & Solutions

#### 1. Smooth Marquee Animation

**Problem**: I needed a dashed line that flows continuously around the screen edges.

**First attempt**: `CABasicAnimation` on `lineDashPhase`:
```swift
let anim = CABasicAnimation(keyPath: "lineDashPhase")
anim.fromValue = 0
anim.toValue = perimeter
anim.repeatCount = .infinity
shape.add(anim, forKey: "flow")
```

**Issue**: When the window was hidden and shown again, Core Animation lost the animation state. The marquee would freeze or reverse direction.

**Solution**: Timer-driven animation at 60fps:
```swift
flowTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
    let speed = perimeter / animationDuration
    dashPhase += speed * dt
    ringLayer.sublayers?.forEach { layer in
        (layer as? CAShapeLayer)?.lineDashPhase = dashPhase
    }
}
```

This bypasses Core Animation's animation system entirely. No state loss, no glitches.

#### 2. Realistic Neon Glow Effect

**Problem**: How to make the glow look like a real neon light tube?

**Solution**: Stack 4 CAShapeLayer instances with different blur levels and opacities:
```swift
// Layer 1: Outer glow
let shape1 = CAShapeLayer()
shape1.lineWidth = baseWidth * 1.5
shape1.strokeColor = color.withAlphaComponent(0.15).cgColor
let blur1 = CIFilter(name: "CIGaussianBlur")!
blur1.setValue(12.0, forKey: "inputRadius")
shape1.filters = [blur1]

// Layer 2: Mid glow (blur 8, alpha 0.30)
// Layer 3: Core line (blur 2, alpha 0.70)
// Layer 4: Bright center (no blur, alpha 0.95)
```

The result looks like a real neon light.

#### 3. Multi-Monitor Support

**Problem**: How to handle multiple displays with different sizes?

**Solution**: Calculate the union of all screen frames:
```swift
func totalScreenFrame() -> NSRect {
    var frame = NSRect.zero
    for screen in NSScreen.screens {
        frame = NSUnionRect(frame, screen.frame)
    }
    return frame
}
```

Listen to `NSApplication.didChangeScreenParametersNotification` and rebuild layers with 500ms debounce.

#### 4. Settings Persistence

**Problem**: How to make settings reactive and persist them?

**Solution**: `ObservableObject` + `UserDefaults` + Combine:
```swift
class AppSettings: ObservableObject {
    @Published var speed: Int {
        didSet { UserDefaults.standard.set(speed, forKey: "speed") }
    }
    
    static let shared = AppSettings()
    
    private init() {
        self.speed = UserDefaults.standard.integer(forKey: "speed")
        if speed == 0 { speed = 5 } // default
    }
}
```

Then in GlowWindow:
```swift
settings.$speed.sink { [weak self] _ in
    self?.rebuildLayers()
}.store(in: &cancellables)
```

### Code Quality

- Pure Swift + SwiftUI, no third-party dependencies
- Clean separation: GlowWindow / ControlServer / Settings / Themes
- Bilingual (Chinese & English)
- ~892KB, ~0% CPU, ~50MB RAM

### Links

- **GitHub**: https://github.com/vector4wang/EdgeGlow
- **Demo**: https://github.com/vector4wang/EdgeGlow/raw/main/Resources/demo.gif

Would love feedback on the Core Animation approach or any SwiftUI best practices I might have missed!

---

## r/LocalLLaMA 版本

### 标题
```
[Tool] EdgeGlow – Visual feedback for Claude Code / AI coding agents (macOS, open-source)
```

### 正文

Hey r/LocalLLaMA!

If you're using Claude Code or other AI coding agents, you know the pain: the AI is working in the terminal, but you can't tell if it's still thinking or waiting for your input.

I built **EdgeGlow** to solve this. It's a free, open-source macOS menu bar app that puts a colorful glow around your screen when the AI is working.

### How It Works

```
AI Agent triggers hook → curl http://127.0.0.1:9876/start → Screen glows
AI Agent finishes     → curl http://127.0.0.1:9876/stop  → Glow fades out
```

### Configuration

In your Claude Code settings (`~/.claude/settings.json`):
```json
{
  "hooks": {
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "curl -s http://127.0.0.1:9876/start"}]}],
    "PreToolUse": [{"hooks": [{"type": "command", "command": "curl -s http://127.0.0.1:9876/start"}]}],
    "PostToolUse": [{"hooks": [{"type": "command", "command": "curl -s http://127.0.0.1:9876/pulse"}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "curl -s http://127.0.0.1:9876/stop"}]}]
  }
}
```

Or just open EdgeGlow settings → Configure Agent Hooks → copy the prompt → paste it into Claude Code chat. The agent will configure it automatically.

### Features

- 🌈 5 color themes
- 🖥️ Multi-monitor support
- 💨 ~0% CPU, 50MB RAM, only 892KB
- 🔒 Privacy first (localhost only, no data collection)
- 📦 Universal Binary (arm64 + x86_64)

### Links

- **GitHub**: https://github.com/vector4wang/EdgeGlow
- **Download**: https://github.com/vector4wang/EdgeGlow/releases

Works great with Claude Code, should work with any agent that can make HTTP requests.

---

## Reddit 发布策略

### 时间选择
- **最佳时间**: 周二/周三/周四 9:00-11:00 AM ET (美东时间)
- **避免**: 周末、美国假期

### 账号要求
- **Karma**: 至少 100+ (避免被当spam)
- **Account age**: 至少 30 天

### 互动要点
1. **发布后1小时**: 必须在线，快速回复评论
2. **回复风格**: 友好、技术导向、感谢反馈
3. **不要**: 跨subreddit交叉发布（选一个主发，其他等1-2周）

### 各 Subreddit 侧重点

| Subreddit | 侧重点 | 用户爽点 |
|-----------|--------|----------|
| r/macapps | 实用性、安装简单 | "终于有个小工具解决这个痛点" |
| r/opensource | 代码质量、MIT协议 | "干净的代码，欢迎PR" |
| r/SwiftUI | 技术实现、CALayer | "Timer vs CABasicAnimation 的权衡" |
| r/LocalLLaMA | AI工作流、Claude Code | "配合AI编程的可视化反馈" |

---

## 预期用户爽点

1. **痛点共鸣**: "对！我也遇到这个问题"
2. **开源免费**: MIT协议，代码干净
3. **技术深度**: Core Animation、4层光效
4. **轻量高效**: 892KB、0% CPU
5. **隐私安全**: 仅本地、无数据收集
6. **AI工作流**: 配合Claude Code使用
