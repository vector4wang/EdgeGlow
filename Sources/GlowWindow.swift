import Cocoa
import Combine

// ============================================================
// MARK: - 流光窗口
// ============================================================
class GlowWindow {
    let window: NSWindow
    let ringLayer = CALayer()
    let settings: AppSettings
    var cancellables = Set<AnyCancellable>()
    private var rebuildWorkItem: DispatchWorkItem?  // 用于 debounce
    private var screenChangeWorkItem: DispatchWorkItem?  // 用于 screen change 限流

    init(settings: AppSettings = .shared) {
        self.settings = settings

        // 使用所有屏幕的最大包围区域，支持多显示器
        var totalFrame = NSRect.zero
        for screen in NSScreen.screens {
            totalFrame = NSUnionRect(totalFrame, screen.frame)
        }
        guard totalFrame.width > 0 else { fatalError("No screen") }

        window = NSWindow(
            contentRect: totalFrame,
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

        let cv = window.contentView!
        cv.wantsLayer = true
        cv.layer = CALayer()

        ringLayer.frame = CGRect(origin: .zero, size: totalFrame.size)
        ringLayer.opacity = 0
        cv.layer!.addSublayer(ringLayer)

        buildLayers(size: totalFrame.size)
        observeSettings()
        observeScreenChanges()

        FileHandle.standardError.write(Data("[edge-glow] ✨ 就绪\n".utf8))
    }

    // MARK: - 监听屏幕变化 (500ms 限流)
    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.screenChangeWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.handleScreenChange()
            }
            self?.screenChangeWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
    }

    private func handleScreenChange() {
        // 获取所有屏幕的最大包围区域
        var totalFrame = NSRect.zero
        for screen in NSScreen.screens {
            totalFrame = NSUnionRect(totalFrame, screen.frame)
        }

        FileHandle.standardError.write(Data("[edge-glow] 屏幕变化 → \(totalFrame.size.width)x\(totalFrame.size.height)\n".utf8))

        // 调整窗口大小
        window.setFrame(totalFrame, display: true)

        // 重建图层
        ringLayer.frame = CGRect(origin: .zero, size: totalFrame.size)
        ringLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        buildLayers(size: totalFrame.size)

        // 如果正在显示，重新应用
        if ringLayer.presentation()?.opacity ?? 0 > 0 {
            ringLayer.opacity = 1.0
        }
    }

    // MARK: - 监听设置变化 (100ms debounce)
    private func observeSettings() {
        let scheduleRebuild = { [weak self] in
            self?.rebuildWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.rebuildLayers()
            }
            self?.rebuildWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
        }

        settings.$speed.sink { _ in scheduleRebuild() }.store(in: &cancellables)
        settings.$width.sink { _ in scheduleRebuild() }.store(in: &cancellables)
        settings.$brightness.sink { _ in scheduleRebuild() }.store(in: &cancellables)
        settings.$themeName.sink { _ in scheduleRebuild() }.store(in: &cancellables)
        settings.$customColors.sink { _ in scheduleRebuild() }.store(in: &cancellables)
        settings.$clockwise.sink { _ in scheduleRebuild() }.store(in: &cancellables)
    }

    private func rebuildLayers() {
        FileHandle.standardError.write(Data("[edge-glow] rebuildLayers called\n".utf8))

        // 使用所有屏幕的 union 尺寸，与 init 一致
        var totalFrame = NSRect.zero
        for screen in NSScreen.screens {
            totalFrame = NSUnionRect(totalFrame, screen.frame)
        }
        guard totalFrame.width > 0 else { return }

        // 清除旧的子图层
        ringLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        buildLayers(size: totalFrame.size)
    }

    // MARK: - 构建图层
    func buildLayers(size: CGSize) {
        let inset: CGFloat = 2
        let rect = CGRect(x: inset, y: inset,
                          width: size.width - inset * 2,
                          height: size.height - inset * 2)
        let path = CGPath(roundedRect: rect, cornerWidth: 0, cornerHeight: 0, transform: nil)
        let perimeter = 2 * (rect.width + rect.height)

        let baseWidth = settings.baseLineWidth
        let brightness = CGFloat(settings.brightness)
        let theme = settings.currentTheme
        let colors = theme.cgColors(alpha: brightness)

        // 多层: (线宽倍率, 透明度倍率, 模糊, 单元比例, 段占比)
        let configs: [(widthMul: CGFloat, alphaMul: CGFloat, blur: Double, unitRatio: CGFloat, dashFrac: CGFloat)] = [
            (baseWidth * 1.5 / 2, 0.15 * brightness, 12.0, 0.20, 0.45),   // 大光晕
            (baseWidth * 0.8 / 2,  0.30 * brightness, 8.0,  0.20, 0.40),   // 中光晕
            (baseWidth * 0.3 / 2,  0.70 * brightness, 2.0,  0.20, 0.35),   // 主色线
            (baseWidth * 0.1 / 2,  0.95 * brightness, 0.0,  0.20, 0.30),   // 亮芯
        ]

        for (lineWidth, alpha, blur, unitRatio, dashFrac) in configs {
            let unitLen = perimeter * unitRatio
            let dashLen = unitLen * dashFrac
            let gapLen = unitLen * (1 - dashFrac)

            let shape = CAShapeLayer()
            shape.frame = ringLayer.bounds
            shape.path = path
            shape.fillColor = nil
            shape.strokeColor = NSColor(red: 0.5, green: 0.6, blue: 1.0, alpha: alpha).cgColor
            shape.lineWidth = max(1, lineWidth)
            shape.lineCap = .round
            shape.lineDashPattern = [NSNumber(value: Double(dashLen)),
                                     NSNumber(value: Double(gapLen))]

            if blur > 0 {
                let bf = CIFilter(name: "CIGaussianBlur")!
                bf.setValue(blur, forKey: "inputRadius")
                shape.filters = [bf]
            }

            ringLayer.addSublayer(shape)

            // 流光动画
            let dashAnim = CABasicAnimation(keyPath: "lineDashPhase")
            dashAnim.fromValue = 0
            dashAnim.toValue = settings.clockwise ? perimeter : -perimeter
            dashAnim.duration = settings.animationDuration
            dashAnim.repeatCount = .infinity
            dashAnim.timingFunction = CAMediaTimingFunction(name: .linear)
            shape.add(dashAnim, forKey: "flow")

            // 颜色循环
            let colorAnim = CAKeyframeAnimation(keyPath: "strokeColor")
            colorAnim.values = colors.map { $0 as Any }
            colorAnim.keyTimes = (0..<colors.count).map {
                NSNumber(value: Double($0) / Double(colors.count - 1))
            }
            colorAnim.duration = settings.animationDuration * 3
            colorAnim.repeatCount = .infinity
            colorAnim.calculationMode = .linear
            shape.add(colorAnim, forKey: "colorCycle")
        }
    }

    // MARK: - 显示/隐藏/脉冲
    func show(mode: String = "thinking") {
        guard settings.enabled else { return }
        window.orderFrontRegardless()

        // 取消正在进行的淡出，防止回调把窗口关掉
        ringLayer.removeAnimation(forKey: "fadeOut")
        ringLayer.removeAnimation(forKey: "pulse")

        // 恢复所有子图层的流动动画
        ringLayer.sublayers?.forEach { layer in
            layer.speed = 1.0
        }

        ringLayer.opacity = 1.0
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1.0
        fade.duration = 1.5
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        ringLayer.add(fade, forKey: "fadeIn")

        FileHandle.standardError.write(Data("[edge-glow] ✨ 流光开启 (思考模式)\n".utf8))
    }

    /// 等待用户输入 — 停止旋转，静态显示
    func pulse() {
        guard settings.enabled else { return }
        window.orderFrontRegardless()

        // 停止淡入动画
        ringLayer.removeAnimation(forKey: "fadeIn")

        // 停止所有子图层的流动动画（跑马灯静止）
        ringLayer.sublayers?.forEach { layer in
            layer.speed = 0.0
        }

        // 保持全亮，不闪烁
        ringLayer.opacity = 1.0

        FileHandle.standardError.write(Data("[edge-glow] ⏸ 等待用户输入 (静止)\n".utf8))
    }

    func hide() {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = ringLayer.presentation()?.opacity ?? 1.0
        fade.toValue = 0
        fade.duration = 1.5
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        fade.delegate = FadeCB { [weak self] in
            self?.window.orderOut(nil)
        }
        ringLayer.add(fade, forKey: "fadeOut")
        ringLayer.opacity = 0
    }

}

class FadeCB: NSObject, CAAnimationDelegate {
    let cb: () -> Void
    init(_ cb: @escaping () -> Void) { self.cb = cb }
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) { cb() }
}
