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

    // CVDisplayLink 驱动流动动画（与屏幕刷新同步，不受 RunLoop 阻塞影响）
    private var displayLink: CVDisplayLink?
    private var dashPhase: CGFloat = 0
    private var lastTickTime: CFTimeInterval = 0
    private var fadeOutWorkItem: DispatchWorkItem?

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

        log("✨ 就绪")
    }

    deinit {
        stopFlow()
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
        log("屏幕变化 → \(totalFrame.size.width)x\(totalFrame.size.height)")

        cachedPerimeter = 0  // 清除缓存
        window.setFrame(totalFrame, display: true)
        ringLayer.frame = CGRect(origin: .zero, size: totalFrame.size)
        rebuildSublayers()

        if isVisible {
            ringLayer.opacity = 1.0
            if settings.glowMode == .flow { startFlow() }
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
        settings.$glowMode.sink { _ in scheduleRebuild() }.store(in: &cancellables)
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

        // 沿屏幕边缘切分成多段，每段独立着色，形成虹彩渐变
        let segmentCount = 20

        let blurLevels: [(lineWidthMul: CGFloat, blur: Double)] = [
            (1.5 / 2, 12.0),   // 最外层：宽 + 大模糊 → 柔和光晕
            (0.8 / 2, 8.0),    // 次外层
            (0.3 / 2, 2.0),    // 次内层：轻微模糊
            (0.1 / 2, 0.0),    // 最内层：锐利亮线
        ]

        for seg in 0..<segmentCount {
            let start = CGFloat(seg) / CGFloat(segmentCount)
            let end = CGFloat(seg + 1) / CGFloat(segmentCount)

            for (blurIdx, blurCfg) in blurLevels.enumerated() {
                let shape = CAShapeLayer()
                shape.frame = ringLayer.bounds
                shape.path = path
                shape.fillColor = nil
                shape.strokeStart = start
                shape.strokeEnd = end
                shape.lineWidth = max(1, baseWidth * blurCfg.lineWidthMul)
                shape.lineCap = .butt
                shape.opacity = 0.5

                if settings.glowMode == .flow {
                    let unitLen = perimeter * 0.20
                    let dashLen = unitLen * (0.45 - Double(blurIdx) * 0.04)
                    let gapLen = unitLen * (1 - (0.45 - Double(blurIdx) * 0.04))
                    shape.lineDashPattern = [NSNumber(value: Double(dashLen)),
                                             NSNumber(value: Double(gapLen))]
                }

                if blurCfg.blur > 0 {
                    let bf = CIFilter(name: "CIGaussianBlur")!
                    bf.setValue(blurCfg.blur, forKey: "inputRadius")
                    shape.filters = [bf]
                }

                ringLayer.addSublayer(shape)

                // 颜色循环：每段错开相位，相邻段颜色不同，边界处被模糊自然过渡
                guard colors.count > 1 else {
                    shape.strokeColor = colors.first
                    continue
                }
                let colorAnim = CAKeyframeAnimation(keyPath: "strokeColor")
                colorAnim.values = colors.map { $0 as Any }
                colorAnim.keyTimes = (0..<colors.count).map {
                    NSNumber(value: Double($0) / Double(colors.count - 1))
                }
                colorAnim.duration = settings.animationDuration * 2
                colorAnim.repeatCount = .infinity
                colorAnim.calculationMode = .linear
                // 段 + 层双重错开：段位置决定色相，层深度决定偏移
                colorAnim.timeOffset = colorAnim.duration * (Double(seg) / Double(segmentCount) + Double(blurIdx) * 0.05)
                shape.add(colorAnim, forKey: "colorCycle")
            }
        }
    }

    // MARK: - CVDisplayLink 驱动流动（与屏幕刷新同步）
    private func startFlow() {
        guard settings.glowMode == .flow else { return }
        stopFlow()
        lastTickTime = CACurrentMediaTime()

        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let displayLink = link else { return }

        // 保存 weak self 引用到上下文
        let context = Unmanaged.passUnretained(self).toOpaque()

        CVDisplayLinkSetOutputCallback(displayLink, { (_, _, _, _, _, userInfo) -> CVReturn in
            guard let userInfo = userInfo else { return kCVReturnSuccess }
            let self_ = Unmanaged<GlowWindow>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async {
                self_.tickFlow()
            }
            return kCVReturnSuccess
        }, context)

        CVDisplayLinkStart(displayLink)
        self.displayLink = displayLink
    }

    private func stopFlow() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
        stopBreathe()
    }

    // MARK: - 呼吸灯动画
    private func startBreathe() {
        guard settings.glowMode == .breathe else { return }
        stopBreathe()
        let baseBreath: CFTimeInterval = settings.animationDuration * 0.7
        ringLayer.sublayers?.enumerated().forEach { i, layer in
            guard let shape = layer as? CAShapeLayer else { return }
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.fromValue = 0.5
            anim.toValue = 1.0
            anim.duration = baseBreath + Double(i) * 0.2
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            shape.add(anim, forKey: "breathe")
        }
    }

    private func stopBreathe() {
        ringLayer.sublayers?.forEach { layer in
            layer.removeAnimation(forKey: "breathe")
        }
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
        fadeOutWorkItem?.cancel()  // 取消自动淡出计划

        // 如果已经在运行，不做任何重建，避免多终端触发时闪烁
        let isRunning = settings.glowMode == .flow ? displayLink != nil : isVisible
        if isVisible && isRunning {
            ringLayer.removeAnimation(forKey: "fadeOut")
            ringLayer.opacity = 1.0
            return
        }

        let wasVisible = isVisible
        isVisible = true
        window.orderFrontRegardless()

        ringLayer.removeAnimation(forKey: "fadeOut")
        ringLayer.removeAnimation(forKey: "fadeIn")

        // 如果之前可见但动画已停（pulse 状态），只重启，不重建图层
        if wasVisible {
            startFlow()
            startBreathe()
            ringLayer.opacity = 1.0
            return
        }

        // 首次显示：完整重建 + 淡入动画
        rebuildSublayers()
        startFlow()
        startBreathe()

        ringLayer.opacity = 1.0
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1.0
        fade.duration = 1.5
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        ringLayer.add(fade, forKey: "fadeIn")

        log("✨ 流光开启")
    }

    /// 脉冲闪亮 — 短暂闪亮后延时自动淡出
    func pulse() {
        guard settings.enabled else { return }
        fadeOutWorkItem?.cancel()  // 取消之前的淡出计划
        stopFlow()
        isVisible = true

        // 短暂亮闪：在 flash 层短暂叠加白色脉冲，即使当前满亮度也有可见效果
        let flashLayer = CAShapeLayer()
        flashLayer.frame = ringLayer.bounds
        flashLayer.path = (ringLayer.sublayers?.first as? CAShapeLayer)?.path
        flashLayer.fillColor = nil
        flashLayer.strokeColor = NSColor.white.withAlphaComponent(0.6).cgColor
        flashLayer.lineWidth = (ringLayer.sublayers?.first as? CAShapeLayer)?.lineWidth ?? 4
        flashLayer.lineCap = .round
        flashLayer.opacity = 0
        ringLayer.addSublayer(flashLayer)

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1.0
        fadeIn.duration = 0.12

        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1.0
        fadeOut.toValue = 0
        fadeOut.beginTime = 0.12
        fadeOut.duration = 0.4

        let group = CAAnimationGroup()
        group.animations = [fadeIn, fadeOut]
        group.duration = 0.52
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            flashLayer.removeFromSuperlayer()
        }
        flashLayer.add(group, forKey: "pulse-flash")
        CATransaction.commit()

        // 保持静态显示
        ringLayer.opacity = 1.0

        // 延时 5 秒后自动淡出（给 Agent 足够时间继续工作）
        let work = DispatchWorkItem { [weak self] in
            self?.autoFadeOut()
        }
        fadeOutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)

        log("💫 脉冲闪亮")
    }

    /// 自动淡出（如果没有新的 start/pulse 触发）
    private func autoFadeOut() {
        // timer 已被 show()/pulse() 取消，走到这里说明没有新的 start，直接灭灯
        hide()
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
        // 把当前相位应用到新图层，避免视觉跳变（仅跑马灯模式）
        if settings.glowMode == .flow {
            ringLayer.sublayers?.forEach { layer in
                (layer as? CAShapeLayer)?.lineDashPhase = dashPhase
            }
        }
        // 呼吸模式下重新启动呼吸动画
        if isVisible && settings.glowMode == .breathe {
            startBreathe()
        }
    }
}
