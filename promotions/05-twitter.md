# Twitter/X 发布文案

## 发布系列

### Post 1: 正式发布 (Launch)

```
My AI coding agent is thinking... and my screen knows it. 🌈

Built EdgeGlow — a free macOS app that shows a glowing marquee around your screen when Claude Code is working.

Done? Lights fade out.

Open source, 892KB, 0 CPU.

https://github.com/vector4wang/EdgeGlow

#buildinpublic #macOS #SwiftUI #OpenSource #AICoding #ClaudeCode
```

---

### Post 2: 技术线程 (Tech Thread)

```
Thread: How I built a neon glow effect around my screen in SwiftUI 🧵

1/ The problem: I needed a dashed line that flows continuously around the screen edges. Simple, right?

2/ First attempt: CABasicAnimation on lineDashPhase. Worked great... until the window was hidden. Core Animation lost state, animation froze or reversed. 🤯

3/ Solution: Ditch Core Animation. Use a 60fps Timer that directly updates lineDashPhase. Bulletproof. No state loss.

4/ The glow effect: 4 CAShapeLayer instances stacked with different blur levels (12, 8, 2, 0) and opacities (0.15, 0.30, 0.70, 0.95). Looks like real neon.

5/ Multi-terminal support: Reference counting. /start increments, /stop decrements. Glow only hides when count reaches 0. Plus 60s safety timeout.

6/ Security: HTTP server binds to 127.0.0.1 only. GET requests only. No CORS headers. No data collection.

Full source: https://github.com/vector4wang/EdgeGlow
```

---

### Post 3: 痛点共鸣 (Pain Point)

```
The worst part about using Claude Code?

Not knowing if the AI is still thinking or waiting for input.

I kept alt-tabbing, breaking my flow.

So I built a tiny macOS app that shows a glow around my screen when the AI is working.

One glance, problem solved. 🌈

https://github.com/vector4wang/EdgeGlow
```

---

### Post 4: 性能炫耀 (Performance)

```
Built a macOS app that:
✅ Shows neon glow around screen
✅ 4 color themes
✅ Multi-monitor support
✅ 892KB size
✅ 0% CPU usage
✅ 50MB RAM
✅ Universal Binary (arm64 + x86_64)

All with pure Swift + SwiftUI, no dependencies.

https://github.com/vector4wang/EdgeGlow
```

---

### Post 5: 视觉冲击 (Visual Demo)

```
AI coding with visual feedback >>> AI coding blind

[Attach demo.gif or screenshot]

EdgeGlow shows a glowing marquee when your AI agent is working.

Free, open-source, 892KB.

https://github.com/vector4wang/EdgeGlow
```

---

## 互动推文

### Reply to comments

**如果有人问 "How does it work?"**
```
It's simple:
1. Claude Code triggers HTTP hooks
2. Hooks call localhost:9876/start
3. EdgeGlow shows glow
4. /stop → glow fades out

Pure Swift + SwiftUI, Core Animation for the neon effect.
```

**如果有人问 "Can it work with X?"**
```
Yes! Any agent that can make HTTP requests. Just configure it to call http://127.0.0.1:9876/start when working and /stop when done.
```

**如果有人问 "What about Windows/Linux?"**
```
Currently macOS only (uses Core Animation). But the code is open-source, so contributions welcome! 🙌
```

---

## Hashtag 策略

### 主要标签 (每条必带)
- #buildinpublic
- #macOS
- #SwiftUI
- #OpenSource

### 次要标签 (选择性使用)
- #AICoding
- #ClaudeCode
- #DeveloperTools
- #Productivity
- #IndieHacker
- #Coding

### 避免
- #AI (太泛，容易被淹没)
- #programming (太大)
- #tech (太泛)

---

## 发布时间策略

### 最佳时间
- **周二-周四**: 9:00-11:00 AM PT (太平洋时间)
- **避开**: 周一早上、周五下午、周末

### 发布节奏
- **Day 1**: Post 1 (正式发布) + Post 5 (视觉)
- **Day 2**: Post 2 (技术线程)
- **Day 3**: Post 3 (痛点共鸣)
- **Day 7**: Post 4 (性能炫耀)

### 互动策略
- **前2小时**: 快速回复每条评论
- **每天**: 回复mention和reply
- **不要**: 自动转发、刷话题标签

---

## 关键指标

### 目标
- **Impressions**: 50K+
- **Engagements**: 500+
- **Link clicks**: 1K+
- **Retweets**: 100+

### 追踪
- 使用 Twitter Analytics 查看数据
- 关注哪些推文表现最好
- 调整后续内容策略

---

## 预期用户爽点

1. **视觉冲击**: 霓虹灯效果很酷
2. **轻量免费**: 892KB、开源
3. **技术深度**: Core Animation、Timer驱动
4. **痛点共鸣**: AI编程的可视化反馈
5. **性能数据**: 0% CPU、50MB RAM
