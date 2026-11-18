import Cocoa

// ============================================================
// MARK: - 多屏流光管理器
// ============================================================
/// 为每个物理屏幕创建一个独立 MetalGlowWindow。
/// 原实现把所有屏幕 union 成一个大矩形，只有贴着外接矩形边缘的屏幕可见，
/// 位于凹位/中间的屏幕完全没有流光；此管理器彻底规避该问题。
/// 渲染采用 Metal 片元着色器（单次 draw call），替代原 CAShapeLayer + CIGaussianBlur
/// 的 60 层全屏离屏模糊，显著降低 GPU 占用。
final class GlowWindowManager {
    static let shared = GlowWindowManager()

    private let settings: AppSettings
    private var windows: [MetalGlowWindow] = []
    private var isVisible = false
    private var screenChangeWorkItem: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?

    private init(settings: AppSettings = .shared) {
        self.settings = settings
        rebuild()
        observeScreenChanges()
    }

    // MARK: - 对外控制（广播到所有屏幕）
    func show() {
        isVisible = true
        windows.forEach { $0.show() }
    }

    func hide() {
        isVisible = false
        windows.forEach { $0.hide() }
    }

    func pulse() {
        windows.forEach { $0.pulse() }
    }

    // MARK: - 屏幕热插拔
    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.screenChangeWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.rebuild()
            }
            self.screenChangeWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
    }

    /// 销毁旧窗口并按当前屏幕列表重建，保持原有可见状态
    private func rebuild() {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map { MetalGlowWindow(settings: settings, screen: $0) }
        log("🖥️ 流光窗口已重建: \(windows.count) 个屏幕")
        if isVisible {
            windows.forEach { $0.show() }
        }
    }
}
