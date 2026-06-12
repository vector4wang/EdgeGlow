import Cocoa

// ============================================================
// MARK: - 颜色主题
// ============================================================
enum ThemeName: String, CaseIterable, Codable {
    case rainbow = "rainbow"
    case pastel  = "pastel"
    case fire    = "fire"
    case ice     = "ice"
    case custom  = "custom"
}

struct ColorTheme {
    let colors: [(r: Double, g: Double, b: Double, a: Double)]

    func cgColors(alpha: CGFloat = 1.0) -> [CGColor] {
        return colors.map {
            NSColor(red: CGFloat($0.r), green: CGFloat($0.g),
                    blue: CGFloat($0.b), alpha: CGFloat($0.a) * alpha).cgColor
        }
    }

    // MARK: - 预设主题

    static let rainbow = ColorTheme(colors: [
        (0.66, 0.33, 0.97, 1), (0.39, 0.40, 0.95, 1),
        (0.23, 0.51, 0.96, 1), (0.05, 0.65, 0.91, 1),
        (0.02, 0.71, 0.83, 1), (0.08, 0.72, 0.65, 1),
        (0.13, 0.77, 0.37, 1), (0.52, 0.80, 0.09, 1),
        (0.92, 0.70, 0.03, 1), (0.98, 0.45, 0.09, 1),
        (0.96, 0.25, 0.37, 1), (0.93, 0.28, 0.60, 1),
        (0.66, 0.33, 0.97, 1),
    ])

    static let pastel = ColorTheme(colors: [
        (0.72, 0.65, 0.90, 1), (0.60, 0.68, 0.92, 1),
        (0.55, 0.75, 0.88, 1), (0.58, 0.80, 0.82, 1),
        (0.65, 0.82, 0.72, 1), (0.75, 0.80, 0.65, 1),
        (0.82, 0.72, 0.70, 1), (0.78, 0.65, 0.80, 1),
        (0.72, 0.65, 0.90, 1),
    ])

    static let fire = ColorTheme(colors: [
        (0.80, 0.10, 0.10, 1), (0.90, 0.20, 0.05, 1),
        (0.95, 0.35, 0.05, 1), (0.98, 0.55, 0.05, 1),
        (0.95, 0.75, 0.10, 1), (0.98, 0.85, 0.20, 1),
        (0.95, 0.55, 0.05, 1), (0.85, 0.20, 0.05, 1),
        (0.80, 0.10, 0.10, 1),
    ])

    static let ice = ColorTheme(colors: [
        (0.85, 0.92, 1.00, 1), (0.65, 0.80, 0.98, 1),
        (0.45, 0.68, 0.95, 1), (0.30, 0.58, 0.90, 1),
        (0.40, 0.72, 0.92, 1), (0.60, 0.85, 0.95, 1),
        (0.80, 0.92, 1.00, 1), (0.65, 0.80, 0.98, 1),
        (0.85, 0.92, 1.00, 1),
    ])

    static func theme(for name: ThemeName) -> ColorTheme {
        switch name {
        case .rainbow: return .rainbow
        case .pastel:  return .pastel
        case .fire:    return .fire
        case .ice:     return .ice
        case .custom:  return .rainbow  // fallback
        }
    }
}
