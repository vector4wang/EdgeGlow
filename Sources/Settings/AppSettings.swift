import Cocoa
import Combine
import ServiceManagement

// ============================================================
// MARK: - 应用设置 (UserDefaults 持久化)
// ============================================================
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    var onPortChanged: ((Int) -> Void)?

    // MARK: - Keys
    private enum Key: String {
        case enabled        = "glow_enabled"
        case autoStart      = "auto_start"
        case themeName      = "theme_name"
        case speed          = "glow_speed"
        case width          = "glow_width"
        case brightness     = "glow_brightness"
        case httpPort       = "http_port"
        case clockwise      = "glow_clockwise"
        case customColors   = "custom_colors"
    }

    // MARK: - Published Properties
    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: Key.enabled.rawValue) }
    }
    @Published var autoStart: Bool {
        didSet {
            defaults.set(autoStart, forKey: Key.autoStart.rawValue)
            applyAutoStart()
        }
    }
    @Published var themeName: ThemeName {
        didSet { defaults.set(themeName.rawValue, forKey: Key.themeName.rawValue) }
    }
    @Published var speed: Double {
        didSet { defaults.set(speed, forKey: Key.speed.rawValue) }
    }
    @Published var width: Double {
        didSet { defaults.set(width, forKey: Key.width.rawValue) }
    }
    @Published var brightness: Double {
        didSet { defaults.set(brightness, forKey: Key.brightness.rawValue) }
    }
    @Published var httpPort: Int {
        didSet {
            let clamped = min(max(httpPort, 1024), 65535)
            if clamped != httpPort { httpPort = clamped; return }
            defaults.set(httpPort, forKey: Key.httpPort.rawValue)
            if httpPort != oldValue { onPortChanged?(httpPort) }
        }
    }
    @Published var clockwise: Bool {
        didSet { defaults.set(clockwise, forKey: Key.clockwise.rawValue) }
    }
    @Published var customColors: [String] {
        didSet { defaults.set(customColors, forKey: Key.customColors.rawValue) }
    }

    // MARK: - Computed
    var currentTheme: ColorTheme {
        if themeName == .custom && !customColors.isEmpty {
            return ColorTheme(colors: customColors.compactMap { hexToRGBA($0) })
        }
        return ColorTheme.theme(for: themeName)
    }

    /// 速度值 → 动画秒数 (speed 1=慢10s, 10=快1.5s)
    var animationDuration: Double {
        return 10.0 - (speed - 1) * (8.5 / 9.0)
    }

    /// 宽度值 → 基础线宽 (width 1=2px, 10=20px)
    var baseLineWidth: CGFloat {
        return 2 + CGFloat(width - 1) * (18.0 / 9.0)
    }

    // MARK: - Init
    private init() {
        self.enabled = UserDefaults.standard.object(forKey: Key.enabled.rawValue) as? Bool ?? true
        self.autoStart = UserDefaults.standard.bool(forKey: Key.autoStart.rawValue)
        let savedTheme = UserDefaults.standard.string(forKey: Key.themeName.rawValue) ?? ThemeName.rainbow.rawValue
        // 迁移：旧版中文 raw value → 英文
        let migrated: [String: String] = ["炫酷": "rainbow", "柔和": "pastel", "烈焰": "fire", "冰雪": "ice", "自定义": "custom"]
        let normalized = migrated[savedTheme] ?? savedTheme
        self.themeName = ThemeName(rawValue: normalized) ?? .rainbow
        self.speed = UserDefaults.standard.object(forKey: Key.speed.rawValue) as? Double ?? 5
        self.width = UserDefaults.standard.object(forKey: Key.width.rawValue) as? Double ?? 5
        self.brightness = UserDefaults.standard.object(forKey: Key.brightness.rawValue) as? Double ?? 0.85
        self.httpPort = UserDefaults.standard.object(forKey: Key.httpPort.rawValue) as? Int ?? 9876
        self.clockwise = UserDefaults.standard.object(forKey: Key.clockwise.rawValue) as? Bool ?? true
        self.customColors = UserDefaults.standard.stringArray(forKey: Key.customColors.rawValue) ?? []
    }

    // MARK: - Auto Start
    private var isApplyingAutoStart = false

    private func applyAutoStart() {
        guard !isApplyingAutoStart else { return }
        if #available(macOS 13.0, *) {
            do {
                if autoStart {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // 回滚属性和 UserDefaults
                isApplyingAutoStart = true
                autoStart = !autoStart
                isApplyingAutoStart = false
                FileHandle.standardError.write(Data("[edge-glow] 自启动设置失败: \(error)\n".utf8))
            }
        }
    }

    // MARK: - Helpers
    private func hexToRGBA(_ hex: String) -> (r: Double, g: Double, b: Double, a: Double)? {
        var hexStr = hex.trimmingCharacters(in: .whitespaces)
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        guard hexStr.count == 6, let val = UInt32(hexStr, radix: 16) else { return nil }
        return (
            r: Double((val >> 16) & 0xFF) / 255,
            g: Double((val >> 8) & 0xFF) / 255,
            b: Double(val & 0xFF) / 255,
            a: 1.0
        )
    }
}
