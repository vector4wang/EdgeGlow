import Cocoa
import Combine

// ============================================================
// MARK: - 工具函数
// ============================================================
private func totalScreenFrame() -> NSRect {
    var frame = NSRect.zero
    for screen in NSScreen.screens {
        frame = NSUnionRect(frame, screen.frame)
    }
    return frame
}

// ============================================================
// MARK: - 流光窗口
// ============================================================
class GlowWindow {
    let window: NSWindow
    let ringLayer = CALayer()
    let settings: AppSettings
    var cancellables = Set<AnyCancellable>()
    private var rebuildWorkItem: DispatchWorkItem?
    private var screenChangeWorkItem: DispatchWorkItem?
    private var isVisible = false
    private var cachedPerimeter: CGFloat = 0

    // Timer 驱动流动动画（不依赖 Core Animation）
    private var flowTimer: Timer?
    private var dashPhase: CGFloat = 0
    private var lastTickTime: CFTimeInterval = 0

    init(settings: AppSettings = .shared) {
        self.settings = settings

        let totalFrame = totalScreenFrame()
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

    // MARK: - 当前周长（带缓存）
    private func currentPerimeter() -> CGFloat {
        if cachedPerimeter > 0 { return cachedPerimeter }
        let frame = totalScreenFrame()
        let inset: CGFloat = 2
        cachedPerimeter = 2 * (frame.size.width - inset * 2 + frame.size.height - inset * 2)
        return cachedPerimeter
    }

    // MARK: - 监听屏幕变化
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
        let totalFrame = totalScreenFrame()
        FileHandle.standardError.write(Data("[edge-glow] 屏幕变化 → \(totalFrame.size.width)x\(totalFrame.size.height)\n".utf8))

        cachedPerimeter = 0  // 清除缓存
        window.setFrame(totalFrame, display: true)
        ringLayer.frame = CGRect(origin: .zero, size: totalFrame.size)
        rebuildSublayers()

        if isVisible {
            ringLayer.opacity = 1.0
        }
    }

    // MARK: - 监听设置变化
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
        rebuildSublayers()
        if isVisible {
            ringLayer.opacity = 1.0
        }
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

        let configs: [(widthMul: CGFloat, alphaMul: CGFloat, blur: Double, unitRatio: CGFloat, dashFrac: CGFloat)] = [
            (baseWidth * 1.5 / 2, 0.15 * brightness, 12.0, 0.20, 0.45),
            (baseWidth * 0.8 / 2,  0.30 * brightness, 8.0,  0.20, 0.40),
            (baseWidth * 0.3 / 2,  0.70 * brightness, 2.0,  0.20, 0.35),
            (baseWidth * 0.1 / 2,  0.95 * brightness, 0.0,  0.20, 0.30),
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

            // 只用 CA 做颜色循环（稳定可靠）
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

    // MARK: - Timer 驱动流动（不依赖 Core Animation 动画系统）
    private func startFlow() {
        stopFlow()
        lastTickTime = CACurrentMediaTime()
        // 不重置 dashPhase，保持当前位置
        flowTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tickFlow()
        }
        RunLoop.main.add(flowTimer!, forMode: .common)
    }

    private func stopFlow() {
        flowTimer?.invalidate()
        flowTimer = nil
    }

    private func tickFlow() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(now - lastTickTime)
        lastTickTime = now

        // 防止 dt 过大（如从后台回来），限制最大 0.1s
        let clampedDt = min(dt, 0.1)

        let perimeter = currentPerimeter()
        guard perimeter > 0, settings.animationDuration > 0 else { return }

        let speed = perimeter / CGFloat(settings.animationDuration)
        dashPhase += speed * clampedDt * (settings.clockwise ? 1 : -1)

        ringLayer.sublayers?.forEach { layer in
            (layer as? CAShapeLayer)?.lineDashPhase = dashPhase
        }
    }

    // MARK: - 显示/隐藏/脉冲
    func show() {
        guard settings.enabled else { return }
        isVisible = true
        window.orderFrontRegardless()

        ringLayer.removeAnimation(forKey: "fadeOut")
        ringLayer.removeAnimation(forKey: "fadeIn")

        rebuildSublayers()
        startFlow()

        ringLayer.opacity = 1.0
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1.0
        fade.duration = 1.5
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        ringLayer.add(fade, forKey: "fadeIn")

        FileHandle.standardError.write(Data("[edge-glow] ✨ 流光开启\n".utf8))
    }

    /// 等待用户输入 — 停止旋转，静态显示
    func pulse() {
        guard settings.enabled else { return }
        isVisible = true
        window.orderFrontRegardless()

        ringLayer.removeAnimation(forKey: "fadeIn")
        ringLayer.removeAnimation(forKey: "fadeOut")

        stopFlow()
        ringLayer.opacity = 1.0

        FileHandle.standardError.write(Data("[edge-glow] ⏸ 等待用户输入 (静止)\n".utf8))
    }

    func hide() {
        isVisible = false
        stopFlow()

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = ringLayer.presentation()?.opacity ?? 1.0
        fade.toValue = 0
        fade.duration = 1.5
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        ringLayer.add(fade, forKey: "fadeOut")
        ringLayer.opacity = 0
    }

    // MARK: - 重建子图层
    private func rebuildSublayers() {
        ringLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let frame = totalScreenFrame()
        buildLayers(size: frame.size)
        // 把当前相位应用到新图层，避免视觉跳变
        ringLayer.sublayers?.forEach { layer in
            (layer as? CAShapeLayer)?.lineDashPhase = dashPhase
        }
    }
}
