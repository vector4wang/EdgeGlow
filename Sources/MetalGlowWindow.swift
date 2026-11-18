import Cocoa
import Combine

// ============================================================
// MARK: - Metal 流光窗口（每个屏幕一个实例）
// ============================================================
/// 用 MetalGlowView 替代 CAShapeLayer + CIGaussianBlur 渲染。
/// 单个 draw call + 解析高斯衰减，消除离屏渲染与逐层合成开销。
final class MetalGlowWindow {
    let window: NSWindow
    let glowView: MetalGlowView
    let settings: AppSettings
    let screen: NSScreen

    private var cancellables = Set<AnyCancellable>()
    private var fadeOutWorkItem: DispatchWorkItem?

    init(settings: AppSettings = .shared, screen: NSScreen) {
        self.settings = settings
        self.screen = screen

        let frame = screen.frame
        window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)))
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.hasShadow = false
        window.isMovable = false
        window.isReleasedWhenClosed = false

        let view = MetalGlowView(frame: NSRect(origin: .zero, size: frame.size))
        view.update(settings: settings)
        window.contentView = view
        self.glowView = view

        observeSettings()
        log("✨ Metal 就绪: \(Int(frame.width))x\(Int(frame.height)) @ \(Int(frame.origin.x)),\(Int(frame.origin.y))")
    }

    func show() {
        guard settings.enabled else { return }
        if glowView.isFullyVisible {
            fadeOutWorkItem?.cancel()
            fadeOutWorkItem = nil
            return
        }
        fadeOutWorkItem?.cancel()
        fadeOutWorkItem = nil
        window.orderFrontRegardless()
        glowView.setVisible(true, animated: true)
    }

    func hide() {
        glowView.setVisible(false, animated: true)
        fadeOutWorkItem?.cancel()

        // 淡出结束后 orderOut，避免全屏透明窗口持续参与 WindowServer 合成
        let work = DispatchWorkItem { [weak self] in
            self?.window.orderOut(nil)
        }
        fadeOutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    func pulse() {
        guard settings.enabled else { return }
        fadeOutWorkItem?.cancel()
        window.orderFrontRegardless()
        glowView.pulse()

        let work = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        fadeOutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
    }

    deinit {
        teardown()
    }

    func close() {
        teardown()
        log("🧹 Metal 窗口已关闭: \(Int(screen.frame.width))x\(Int(screen.frame.height))")
    }

    /// 幂等清理：关闭窗口、停渲染、取消订阅与定时器
    private func teardown() {
        fadeOutWorkItem?.cancel()
        fadeOutWorkItem = nil
        cancellables.removeAll()
        glowView.shutdown()
        window.orderOut(nil)
        window.close()
    }

    private func observeSettings() {
        let refresh = { [weak self] in
            guard let self = self else { return }
            self.glowView.update(settings: self.settings)
        }
        settings.$themeName.sink { _ in refresh() }.store(in: &cancellables)
        settings.$customColors.sink { _ in refresh() }.store(in: &cancellables)
    }
}
