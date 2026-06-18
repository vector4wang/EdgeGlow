# EdgeGlow 推广文案合集

---

## 一、Product Hunt

### Tagline
The ambient screen glow that tells you when your AI agent is thinking

### Description
EdgeGlow is a free, open-source macOS menu bar app that adds a colorful glowing marquee around your screen edges when your AI coding agent (Claude Code, Hermes Agent) is working.

🟢 AI thinking → lights flow around the screen
🔴 Done → lights fade out

No more guessing if your AI is still working. One glance at your screen edge tells you everything.

**Features:**
- 5 color themes (Iridescent, Rainbow, Pastel, Fire, Ice)
- Iridescent theme simulates iPhone Apple Intelligence edge glow — 20-segment perimeter coloring
- Two glow modes: Flow (marquee) + Breathe (opacity pulse)
- Multi-monitor support
- Adjustable speed, width, brightness, direction
- Bilingual (Chinese & English)
- ~0% CPU, ~50MB RAM
- macOS 13.0+, Intel & Apple Silicon

Free & open-source: https://github.com/vector4wang/EdgeGlow

### Maker Comment
Hi Product Hunt! 👋

I built EdgeGlow because when I use Claude Code for programming, I can never tell if the AI is still thinking or if it's waiting for my input. I kept alt-tabbing to check, which broke my flow.

So I made a tiny macOS app that shows a glowing marquee around my screen when the AI is working. It's that simple.

The tech is all SwiftUI + CALayer — the marquee uses 4 layered CAShapeLayer with Gaussian blur to create a realistic neon glow effect, driven by CVDisplayLink for screen-sync animation. The iridescent theme uses 20-segment perimeter coloring with staggered color cycles to simulate iPhone's Apple Intelligence edge glow.

It's free, open-source (MIT), and weighs only 892KB. Would love your feedback!

---

## 二、Hacker News

### Title
Show HN: EdgeGlow – Screen glow effect for AI coding agents (macOS, Swift)

### First Comment
Hi HN,

I built a small macOS menu bar app that renders a glowing marquee around screen edges when AI coding agents (Claude Code, Hermes Agent) are working.

The problem: When using Claude Code, I can't tell if the AI is still thinking or waiting for input. I keep checking, which breaks flow.

The solution: HTTP hooks in the agent config call a local server (127.0.0.1:9876), which triggers glow state changes:
- /start → flowing marquee (AI thinking)
- /stop → fade out (done)

Technical details:
- Pure Swift + SwiftUI, no dependencies
- 4-layer CAShapeLayer with CIGaussianBlur for neon effect
- `Timer`-driven lineDashPhase animation (not CABasicAnimation — more reliable across window state changes)
- Reference counting for multi-terminal support (PID-based with 120s safety timeout)
- Reference counting for multi-terminal support (PID-based with 120s safety timeout)
- Universal Binary (arm64 + x86_64), ~892KB zipped

Source: https://github.com/vector4wang/EdgeGlow

Built it over a weekend because I wanted visual feedback for my AI coding workflow. Happy to answer questions about the Core Animation approach.

---

## 三、Reddit

### r/macapps + r/opensource + r/LocalLLaMA

**Title:** [Free & Open Source] EdgeGlow – A screen glow effect that shows when your AI coding agent is thinking

**Body:**
I made a small macOS menu bar app called EdgeGlow. When Claude Code or Hermes Agent is working, colorful lights flow around your screen edges. When it's done, they fade out.

No more guessing if your AI is still thinking.

![demo](https://github.com/vector4wang/EdgeGlow/raw/main/Resources/demo.gif)

**What it does:**
- You configure HTTP hooks in Claude Code / Hermes Agent
- When the agent triggers events (UserPromptSubmit, PreToolUse, etc.), it calls localhost:9876
- EdgeGlow shows/hides the glow accordingly

**Features:**
- 4 color themes
- Multi-monitor support
- ~0% CPU, 50MB RAM
- macOS 13.0+, Intel & Apple Silicon
- Only 892KB

**Tech:** Pure Swift + SwiftUI, CALayer animations, NWListener for the HTTP server.

GitHub: https://github.com/vector4wang/EdgeGlow

Feedback welcome! This is my first macOS app.

---

## 四、Dev.to

### Title: Why Your AI Coding Agent Needs Visual Feedback (and how I built EdgeGlow)

**Body:**

If you use Claude Code or similar AI coding agents, you know the pain: the AI is working in the terminal, but you can't tell if it's still thinking or waiting for your input. You keep alt-tabbing, breaking your flow.

I built **EdgeGlow** to solve this. It's a free, open-source macOS menu bar app that puts a colorful glow around your screen when the AI is working.

## How It Works

```
AI Agent triggers hook → curl http://127.0.0.1:9876/start → Screen glows
AI Agent finishes     → curl http://127.0.0.1:9876/stop  → Glow fades out
```

That's it. Dead simple.

## The Technical Challenge

The interesting part was the animation. I needed a smooth marquee effect around the screen edges — essentially a dashed line that flows continuously.

### Why Not CABasicAnimation?

My first approach used `CABasicAnimation` on `lineDashPhase`:

```swift
let anim = CABasicAnimation(keyPath: "lineDashPhase")
anim.fromValue = 0
anim.toValue = perimeter
anim.repeatCount = .infinity
shape.add(anim, forKey: "flow")
```

This worked... until the window was hidden and shown again. Core Animation would lose the animation state, and the marquee would freeze or even reverse direction.

### The Solution: Timer-Driven Animation

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

### The 4-Layer Glow Effect

To create a realistic neon glow, I stack 4 CAShapeLayer instances:

1. **Layer 1**: Wide line, CIGaussianBlur(12), low alpha → outer glow
2. **Layer 2**: Medium line, blur(8), medium alpha → mid glow
3. **Layer 3**: Thin line, blur(2), high alpha → core line
4. **Layer 4**: Thinnest line, no blur, full alpha → bright center

The result looks like a real neon light tube.

### Multi-Terminal Reference Counting

A subtle problem: if you have multiple Claude Code terminals running, one calling `/stop` would kill the glow even though others are still active.

Solution: reference counting. `/start` increments, `/stop` decrements. Only hide when count reaches 0. Plus a 60-second safety timeout in case an agent crashes without sending `/stop`.

## Try It

- **GitHub**: https://github.com/vector4wang/EdgeGlow
- **Download**: https://github.com/vector4wang/EdgeGlow/releases
- **Size**: 892KB zipped
- **License**: MIT
- **macOS**: 13.0+ (Ventura)

It's my first macOS app. Built with pure Swift + SwiftUI, no third-party dependencies.

Would love to hear your feedback!

---

## 五、Twitter/X

### Post 1 (Launch)
My AI coding agent is thinking... and my screen knows it. 🌈

Built EdgeGlow — a free macOS app that shows a glowing marquee around your screen when Claude Code is working.

Done? Lights fade out.

Open source, 892KB, 0 CPU.

https://github.com/vector4wang/EdgeGlow

#buildinpublic #macOS #SwiftUI #OpenSource #AICoding #ClaudeCode

### Post 2 (Demo thread)
Thread: How I built a neon glow effect around my screen in SwiftUI 🧵

1/ I use 4 CAShapeLayer instances stacked on top of each other, each with different blur levels and opacities

2/ The "flow" animation? Not CABasicAnimation. I use a 60fps Timer that updates lineDashPhase directly. More reliable.

3/ The glow fades in/out with CABasicAnimation on opacity. Simple but effective.

Full source: https://github.com/vector4wang/EdgeGlow

---

## 六、掘金

### 标题
我用 SwiftUI 做了个开源小工具，让 AI 编程时屏幕边缘发光 🌈

### 正文

## 前言

用 Claude Code 写代码的时候，有个痛点：**你永远不知道 AI 是在思考还是在等你操作**。经常 alt-tab 切过去看，打断自己的心流。

所以我做了 **EdgeGlow** —— 一个 macOS 菜单栏小工具，AI 工作时屏幕边缘会亮起流光效果，完成了就自动消失。

## 效果

![demo](Resources/demo.gif)

- 🟢 AI 思考中 → 流光旋转流动
- 🔴 完成/等待 → 流光淡出消失

## 原理

很简单：

1. Claude Code 的 hooks 配置会在特定事件触发时调用 `curl http://127.0.0.1:9876/start`
2. EdgeGlow 内置的 HTTP 服务器收到请求后，触发流光动画
3. 收到 `/stop` 后，流光淡出

## 技术亮点

### 四层光效模拟霓虹灯

```
Layer 1: 宽线 + 高斯模糊(12) + 低透明度 → 外层光晕
Layer 2: 中线 + 模糊(8)  + 中透明度 → 中层光晕  
Layer 3: 细线 + 模糊(2)  + 高透明度 → 主线
Layer 4: 最细 + 无模糊    + 全透明度 → 亮芯
```

四层叠加 = 真实的霓虹灯效果。

### 为什么不用 CABasicAnimation？

一开始用 `CABasicAnimation` 做 `lineDashPhase` 动画，但窗口隐藏再显示后，动画会卡住甚至反转。

改用 **Timer 驱动**：

```swift
flowTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) {
    dashPhase += speed * dt
    sublayers.forEach { $0.lineDashPhase = dashPhase }
}
```

不依赖 Core Animation 的动画系统，窗口怎么切换都不会出问题。

### 多终端引用计数

多个 Claude Code 终端同时跑？一个 `/stop` 不会灭掉流光 —— 用引用计数，全部停了才灭。

## 安装

```bash
# 下载 Release
# https://github.com/vector4wang/EdgeGlow/releases

# 或源码编译
git clone https://github.com/vector4wang/EdgeGlow.git
cd EdgeGlow && ./build.sh && open Build/EdgeGlow.app
```

## 配置

打开设置 → 配置 Agent Hooks → 复制引导词 → 发给 Claude Code → 自动配置完成。

## 链接

- GitHub: https://github.com/vector4wang/EdgeGlow
- 协议: MIT
- 大小: 892KB
- 系统: macOS 13.0+ (Ventura)

---

## 七、V2EX

### 节点: /go/macos 或 /go/open_source

### 标题
做了一个开源小工具 EdgeGlow，AI 编程时屏幕边缘会发光

### 正文

各位 V 友好，

周末做了个小工具 —— **EdgeGlow**。

用 Claude Code 写代码时，AI 在后台思考，你看不见它是否在忙。EdgeGlow 在屏幕边缘显示流光效果：AI 工作时流光旋转，完成后淡出。

就是这样，很简单。

**技术栈**: 纯 Swift + SwiftUI，CAShapeLayer + Timer 驱动动画，NWListener HTTP 服务器。无第三方依赖。

**特性**:
- 4 种颜色主题
- 多显示器支持
- 多终端引用计数（多个 AI 同时工作不会误灭）
- ~0% CPU, ~50MB 内存
- 只有 892KB

GitHub: https://github.com/vector4wang/EdgeGlow

第一个 macOS 应用，欢迎提意见。

---

## 八、知乎

### 标题
AI 编程时代，你的开发环境需要怎样的可视化反馈？

### 正文

（长文，建议 2000-3000 字，包含：）
- AI 编程的现状和痛点（看不见 AI 状态）
- EdgeGlow 的设计理念（环境感知、不干扰）
- 技术实现细节（四层光效、Timer 动画、引用计数）
- 使用效果对比
- 开源地址和安装方式

建议以"开发者体验"为切入点，写成一篇有深度的技术+产品思考文章。

---

## 九、少数派

### 标题
EdgeGlow：让 AI 编程过程「可见」的 macOS 开源工具

### 正文要点

1. **引言**: AI 编程工具的普及，开发者需要更好的状态感知
2. **工具介绍**: EdgeGlow 是什么，解决什么问题
3. **安装与配置**: 详细图文教程
4. **功能详解**: 4 种主题、多显示器、设置界面
5. **技术背景**: SwiftUI 原生应用、轻量高效
6. **适用场景**: Claude Code、Hermes Agent 等 AI 编程场景
7. **总结**: 小工具大作用，提升 AI 编程体验

少数派注重**高质量配图和详细教程**，建议准备 5-8 张高清截图。

---

## 十、小红书

### 标题
程序员的浪漫✨AI思考时屏幕会发光！

### 正文
发现一个超酷的开源小工具！

用 Claude Code 写代码的时候，屏幕边缘会有流光效果跟着AI的状态变化 🌈

AI在想事情 → 光在跑
AI做完了 → 光消失

就像给屏幕加了个呼吸灯一样，太酷了！

而且才 892KB，几乎不占资源 🫶

配置也超简单，复制一句话发给 Claude Code 就自动搞定了

#macOS #程序员工具 #开源 #AI编程 #Claude #效率工具 #开发者必备

---

## 十一、微信公众号

### 标题
我用 SwiftUI 做了一个开源工具，让 AI 编程时屏幕会「发光」

### 大纲

1. 引入：AI 编程的痛点
2. EdgeGlow 是什么 + 效果展示（GIF）
3. 技术实现原理
4. 安装和使用指南
5. 开源地址 + 结语

建议投稿给 GitHubDaily、OSCHINA 等技术公众号。

---

## 十二、B站

### 标题
AI编程时屏幕会发光？这个开源工具太酷了！【EdgeGlow】

### 视频大纲（3-5分钟）

1. **开场** (30s): 展示效果，吸引注意
2. **痛点** (30s): AI编程时看不见状态
3. **介绍** (1min): EdgeGlow 是什么，怎么安装
4. **演示** (1min): 实际使用场景，Claude Code 配合
5. **技术** (1min): SwiftUI 实现原理，四层光效
6. **结尾** (30s): GitHub 地址，欢迎 Star

封面文字建议: "AI编程时屏幕发光？！" + EdgeGlow 效果截图

---

## 发布节奏建议

| 时间 | 平台 | 内容 |
|------|------|------|
| Day 1 | Product Hunt + HN + Twitter | 正式发布 |
| Day 2-3 | Reddit + Dev.to | 技术文章 |
| Week 1 | 掘金 + V2EX + 知乎 | 中文技术社区 |
| Week 2 | 小红书 + B站 | 视觉内容 |
| Week 2-3 | 少数派 + 微信公众号 | 深度文章 |
