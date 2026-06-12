# ✦ EdgeGlow

> AI 编程时的屏幕流光特效 — 让你的 Claude Code / Hermes Agent 思考过程可见

[English](#english) | [中文](#中文)

---

## 中文

### ✨ 特性

- 🌈 **流光跑马灯** — 多彩光带沿屏幕边缘流动，AI 思考时自动亮起
- 🎯 **三态感知** — 流光转动(思考中) / 静止(等你输入) / 熄灭(已完成)
- 🖥️ **多显示器支持** — 自动适配所有屏幕，插拔显示器动态响应
- 🎨 **4 种主题** — 炫酷彩虹 / 柔和马卡龙 / 烈焰 / 冰雪
- ⚙️ **全参数可调** — 速度、宽度、亮度、旋转方向
- 🔌 **多 Agent 支持** — Claude Code / Hermes Agent hooks 自动配置
- 🌍 **中英双语** — 自动跟随系统语言
- 🚀 **轻量高效** — CPU ~0%，内存 ~50MB，开机自启

### 📸 效果

| 状态 | 效果 |
|------|------|
| 🟢 AI 思考中 | 流光沿屏幕边缘旋转流动 |
| 🟡 等待输入 | 流光静止，提示你可以操作 |
| 🔴 已完成 | 流光淡出消失 |

### 🚀 安装

#### 方式一：下载 DMG（推荐）

前往 [Releases](../../releases) 下载最新版本。

> ⚠️ 首次打开如遇「无法验证开发者」提示，请 **右键 → 打开** 即可。

#### 方式二：源码编译

```bash
# 克隆仓库
git clone https://github.com/vector4wang/EdgeGlow.git
cd EdgeGlow

# 编译（自动构建 Universal Binary）
./build.sh

# 运行
open Build/EdgeGlow.app
```

### 🔌 Claude Code 配置

EdgeGlow 启动时会自动检测并提示配置 hooks，也支持一键自动写入。

手动配置：在 `~/.claude/settings.json` 中添加：

```json
{
  "hooks": {
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "curl -s http://127.0.0.1:9876/start"}]}],
    "PreToolUse": [{"hooks": [{"type": "command", "command": "curl -s http://127.0.0.1:9876/start"}]}],
    "PostToolUse": [{"hooks": [{"type": "command", "command": "curl -s http://127.0.0.1:9876/pulse"}]}],
    "PermissionRequest": [{"hooks": [{"type": "command", "command": "curl -s http://127.0.0.1:9876/pulse"}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "curl -s http://127.0.0.1:9876/stop"}]}]
  }
}
```

### 🤖 Hermes Agent 配置

EdgeGlow 也支持为 Hermes Agent 自动安装 hooks（`~/.hermes/agent-hooks/`）。

### ⚙️ 设置

菜单栏图标 → 设置，可调整：
- 颜色主题（4 种预设）
- 流光速度 / 光带宽度 / 亮度
- 旋转方向（顺时针 / 逆时针）
- 开机自启动
- HTTP 端口（默认 9876）

### 📐 技术架构

```
Swift + Cocoa (NSWindow + CALayer)
├── GlowWindow        — 透明全屏覆盖窗口 + CAShapeLayer 流光动画
├── ControlServer     — NWListener HTTP 服务器 (127.0.0.1)
├── HooksInstaller    — Claude Code / Hermes Agent hooks 自动配置
├── AppSettings       — UserDefaults 持久化 + Combine 响应式绑定
└── L10n              — 中英双语国际化
```

### 📦 系统要求

- macOS 13.0+
- 支持 Intel (x86_64) 和 Apple Silicon (arm64)

---

## English

### ✨ Features

- 🌈 **Marquee Glow** — Colorful light band flows along screen edges when AI is thinking
- 🎯 **Three States** — Spinning (thinking) / Static (waiting) / Faded (done)
- 🖥️ **Multi-Monitor** — Auto-adapts to all displays, dynamic response to changes
- 🎨 **4 Themes** — Rainbow / Pastel / Fire / Ice
- ⚙️ **Full Control** — Speed, width, brightness, rotation direction
- 🔌 **Multi-Agent** — Auto-configures hooks for Claude Code / Hermes Agent
- 🌍 **Bilingual** — Chinese & English, auto-detects system language
- 🚀 **Lightweight** — ~0% CPU, ~50MB RAM, launch at login

### 🚀 Install

#### Option 1: Download DMG

Go to [Releases](../../releases) and download the latest version.

> ⚠️ If you see "Cannot verify developer", **right-click → Open** to launch.

#### Option 2: Build from Source

```bash
git clone https://github.com/vector4wang/EdgeGlow.git
cd EdgeGlow
./build.sh
open Build/EdgeGlow.app
```

### 🔌 Claude Code Setup

EdgeGlow auto-detects and prompts for hooks configuration on first launch.

### ⚙️ Settings

Menu bar icon → Settings to adjust themes, speed, width, brightness, direction, auto-start, and HTTP port.

---

## ☕ 赞助 / Donate

如果 EdgeGlow 对你有用，欢迎请作者喝杯咖啡 ☕

If EdgeGlow is useful to you, feel free to buy me a coffee ☕

| 支付宝 / Alipay | 微信支付 / WeChat Pay |
|:---:|:---:|
| <img src="Resources/zfb.png" width="200"> | <img src="Resources/wx.png" width="200"> |

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ for AI-powered developers
</p>
