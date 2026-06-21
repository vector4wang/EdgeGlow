import Foundation

// ============================================================
// MARK: - 国际化 (中文 / English)
// ============================================================
enum Lang {
    case zh, en

    static var current: Lang {
        let preferred = Locale.preferredLanguages.first ?? "zh"
        return preferred.hasPrefix("zh") ? .zh : .en
    }
}

// 快捷函数
func L(_ key: String) -> String {
    return L10n.shared.translate(key)
}

class L10n {
    static let shared = L10n()
    let lang: Lang = Lang.current

    private let dict: [String: (zh: String, en: String)] = [

        // MARK: - 设置窗口
        "settings.title":          ("✦ EdgeGlow 设置", "✦ EdgeGlow Settings"),
        "settings.general":        ("通用", "General"),
        "settings.enabled":        ("启用流光", "Enable Glow"),
        "settings.enabled.help":   ("关闭后 AI 不会触发流光效果", "Glow won't activate when AI is working"),
        "settings.autoStart":      ("开机自启动", "Launch at Login"),
        "settings.autoStart.help": ("登录系统时自动启动 EdgeGlow", "Start EdgeGlow automatically at login"),
        "settings.autoStart.unsupported": ("开机自启动需要 macOS 13 或更高版本", "Launch at Login requires macOS 13 or later"),

        "settings.appearance":     ("外观", "Appearance"),
        "settings.theme":          ("颜色主题", "Color Theme"),
        "settings.speed":          ("速度", "Speed"),
        "settings.width":          ("光带宽度", "Width"),
        "settings.brightness":     ("亮度", "Brightness"),
        "settings.direction":      ("旋转方向", "Direction"),
        "settings.clockwise":      ("顺时针", "Clockwise"),
        "settings.counterCW":      ("逆时针", "Counterclockwise"),
        "settings.mode":           ("流光模式", "Glow Mode"),
        "mode.flow":               ("跑马灯", "Flow"),
        "mode.breathe":            ("呼吸灯", "Breathe"),

        "settings.advanced":       ("高级", "Advanced"),
        "settings.httpPort":       ("HTTP 端口", "HTTP Port"),
        "settings.configHooks":    ("配置 Agent Hooks", "Configure Agent Hooks"),
        "settings.hooksHint":      ("Claude Code 通过 %@/start 和 /stop 控制流光",
                                    "Claude Code controls glow via %@/start and /stop"),

        // MARK: - 主题名
        "theme.rainbow":           ("🌈 炫酷", "🌈 Rainbow"),
        "theme.pastel":            ("🌊 柔和", "🌊 Pastel"),
        "theme.fire":              ("🔥 烈焰", "🔥 Fire"),
        "theme.ice":               ("❄️ 冰雪", "❄️ Ice"),
        "theme.iridescent":        ("✨ 虹彩", "✨ Iridescent"),

        // MARK: - 菜单栏
        "menu.enabled":            ("✓ 流光已启用", "✓ Glow Enabled"),
        "menu.disabled":           ("✗ 流光已禁用", "✗ Glow Disabled"),
        "menu.turnOn":             ("开启流光", "Turn On Glow"),
        "menu.turnOff":            ("关闭流光", "Turn Off Glow"),
        "menu.settings":           ("设置…", "Settings…"),
        "menu.feedback":           ("反馈问题", "Feedback"),
        "menu.quit":               ("退出 EdgeGlow", "Quit EdgeGlow"),

        // MARK: - Hooks 引导
        "hooks.dialog.title":      ("配置 Agent 联动", "Configure Agent Integration"),
        "hooks.viewConfig":        ("查看配置", "View Config"),
        "hooks.cancel":            ("取消", "Cancel"),

        "hooks.cc.title":          ("Claude Code 配置引导", "Claude Code Setup Guide"),
        "hooks.cc.msg":            ("复制下方提示词，粘贴到 Claude Code 对话框中发送，Agent 会自动帮你完成配置：\n\n%@",
                                    "Copy the prompt below and paste it into Claude Code. The agent will configure hooks for you:\n\n%@"),
        "hooks.cc.copy":           ("复制提示词", "Copy Prompt"),
        "hooks.cc.close":          ("关闭", "Close"),

        "hooks.hermes.title":      ("Hermes Agent 配置引导", "Hermes Agent Setup Guide"),
        "hooks.hermes.msg":        ("复制下方提示词，粘贴到 Hermes Agent 对话框中发送，Agent 会自动帮你完成配置：\n\n%@",
                                    "Copy the prompt below and paste it into Hermes Agent. The agent will configure hooks for you:\n\n%@"),
        "hooks.hermes.copy":       ("复制提示词", "Copy Prompt"),
        "hooks.hermes.close":      ("关闭", "Close"),

        // MARK: - 启动提示
        "launch.notification.title": ("✦ EdgeGlow 已就绪", "✦ EdgeGlow Ready"),
        "launch.notification.body":  ("点击菜单栏图标查看使用说明\n当 Agent 工作时，流光会自动亮起",
                                      "Click menu bar icon for usage\nGlow activates when Agent is working"),
    ]

    func translate(_ key: String) -> String {
        guard let entry = dict[key] else { return key }
        return lang == .zh ? entry.zh : entry.en
    }
}
