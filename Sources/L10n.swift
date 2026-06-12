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

        "settings.appearance":     ("外观", "Appearance"),
        "settings.theme":          ("颜色主题", "Color Theme"),
        "settings.speed":          ("速度", "Speed"),
        "settings.width":          ("光带宽度", "Width"),
        "settings.brightness":     ("亮度", "Brightness"),
        "settings.direction":      ("旋转方向", "Direction"),
        "settings.clockwise":      ("顺时针", "Clockwise"),
        "settings.counterCW":      ("逆时针", "Counterclockwise"),

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

        // MARK: - 菜单栏
        "menu.enabled":            ("✓ 流光已启用", "✓ Glow Enabled"),
        "menu.disabled":           ("✗ 流光已禁用", "✗ Glow Disabled"),
        "menu.turnOn":             ("开启流光", "Turn On Glow"),
        "menu.turnOff":            ("关闭流光", "Turn Off Glow"),
        "menu.settings":           ("设置…", "Settings…"),
        "menu.feedback":           ("反馈问题", "Feedback"),
        "menu.quit":               ("退出 EdgeGlow", "Quit EdgeGlow"),

        // MARK: - Hooks 安装
        "hooks.dialog.title":      ("配置 Agent 联动", "Configure Agent Integration"),
        "hooks.dialog.subtitle":   ("选择要配置的 AI 编程助手：", "Select an AI coding assistant to configure:"),
        "hooks.configured":        ("✓ 已配置", "✓ Configured"),
        "hooks.notConfigured":     ("未配置", "Not Configured"),
        "hooks.cancel":            ("取消", "Cancel"),
        "hooks.reconfigure.title": ("%@ 已配置", "%@ Already Configured"),
        "hooks.reconfigure.msg":   ("是否重新配置？", "Reconfigure?"),
        "hooks.reconfigure.btn":   ("重新配置", "Reconfigure"),
        "hooks.success.title":     ("配置完成", "Configuration Complete"),
        "hooks.success.msg":       ("%@ hooks 已成功写入。\n重启 %@ 后即可生效。",
                                    "%@ hooks installed.\nRestart %@ to take effect."),
        "hooks.success.ok":        ("好的", "OK"),
        "hooks.error.title":       ("写入失败", "Write Failed"),
        "hooks.error.msg":         ("无法为 %@ 写入 hooks：\n%@",
                                    "Failed to write hooks for %@:\n%@"),
        "hooks.error.ok":          ("确定", "OK"),
    ]

    func translate(_ key: String) -> String {
        guard let entry = dict[key] else { return key }
        return lang == .zh ? entry.zh : entry.en
    }
}
