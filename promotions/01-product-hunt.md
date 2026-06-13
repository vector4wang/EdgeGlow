# Product Hunt 发布文案

## 基本信息

**产品名称**: EdgeGlow

**Tagline**: The ambient screen glow that tells you when your AI agent is thinking

**Category**: Developer Tools / Productivity

**Website**: https://github.com/vector4wang/EdgeGlow

---

## 产品描述 (Description)

EdgeGlow is a free, open-source macOS menu bar app that adds a colorful glowing marquee around your screen edges when your AI coding agent (Claude Code, Hermes Agent) is working.

### The Problem It Solves

When you're using AI coding agents like Claude Code, you can't tell if the AI is still thinking or waiting for your input. You keep alt-tabbing to check, breaking your flow state.

### The Solution

EdgeGlow puts a glowing marquee around your screen edges:

```
🟢 AI thinking → lights flow around the screen
🔴 Done → lights fade out
```

One glance at your screen edge tells you everything. No more guessing.

![EdgeGlow Effect](https://github.com/vector4wang/EdgeGlow/raw/main/images/效果界面.jpg)

### Key Features

![Settings Interface](https://github.com/vector4wang/EdgeGlow/raw/main/images/设置界面.jpg)

✨ **4 Color Themes**
- 🌈 Rainbow (vibrant, eye-catching)
- 🌊 Pastel (calm, night-friendly)
- 🔥 Fire (warm, energetic)
- ❄️ Ice (cool, focused)

🖥️ **Multi-Monitor Support**
- Automatically adapts to all connected displays
- Handles display hot-plugging with 500ms debounce

⚙️ **Fully Customizable**
- Adjustable speed (1-10)
- Adjustable width (1-10)
- Adjustable brightness (0.3-1.0)
- Clockwise/counterclockwise direction

🌐 **Bilingual**
- Chinese & English interface

💨 **Ultra Lightweight**
- ~0% CPU usage
- ~50MB RAM
- Only 892KB zipped

🔒 **Privacy First**
- HTTP server binds to 127.0.0.1 only (not accessible from network)
- Only accepts GET requests
- No CORS headers (web JavaScript cannot invoke)
- No data collection, no telemetry
- No third-party dependencies

📦 **Requirements**
- macOS 13.0+ (Ventura)
- Intel & Apple Silicon (Universal Binary)

---

## Maker Comment

Hi Product Hunt! 👋

I built EdgeGlow because when I use Claude Code for programming, I can never tell if the AI is still thinking or if it's waiting for my input. I kept alt-tabbing to check, which broke my flow.

So I made a tiny macOS app that shows a glowing marquee around my screen when the AI is working. It's that simple.

### The Tech Behind It

The marquee uses 4 layered CAShapeLayer instances with CIGaussianBlur to create a realistic neon glow effect:

```
Layer 1: Wide line + blur(12) + low alpha → outer glow
Layer 2: Medium line + blur(8) + medium alpha → mid glow
Layer 3: Thin line + blur(2) + high alpha → core line
Layer 4: Thinnest line + no blur + full alpha → bright center
```

The flow animation is driven by a 60fps Timer that directly updates `lineDashPhase` — not CABasicAnimation, which loses state when windows are hidden/shown.

### Multi-Terminal Support

If you have multiple Claude Code terminals running, EdgeGlow uses reference counting. One terminal calling `/stop` won't kill the glow if others are still active. Plus a 60-second safety timeout in case an agent crashes without sending `/stop`.

It's free, open-source (MIT), and weighs only 892KB. Would love your feedback!

**Links:**
- GitHub: https://github.com/vector4wang/EdgeGlow
- Download: https://github.com/vector4wang/EdgeGlow/releases

---

## 发布策略

### 关键指标
- **Upvotes**: 目标 200+
- **Comments**: 积极回复每一条评论
- **Maker Story**: 真实、有技术深度

### 时间选择
- **最佳发布时间**: 周二/周三/周四 00:01 PT (太平洋时间)
- **避免**: 周一(竞争大)、周五(周末流量低)

### 互动要点
1. **前2小时**: 必须在线，快速回复评论
2. **评论区**: 感谢每条upvote，回答技术问题
3. **不要**: 要求朋友刷票、使用自动化工具

### 话题标签
#DeveloperTools #Productivity #OpenSource #macOS #SwiftUI #AI #ClaudeCode

---

## 预期用户爽点

1. **痛点共鸣**: "对！我也遇到这个问题"
2. **视觉冲击**: 霓虹灯效果很酷
3. **轻量免费**: 892KB，开源MIT
4. **技术深度**: Core Animation、多层光效
5. **隐私安全**: 仅本地，无数据收集
