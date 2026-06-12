import Cocoa

// ============================================================
// MARK: - App Delegate
// ============================================================
class AppDelegate: NSObject, NSApplicationDelegate {
    var glow: GlowWindow!
    var server: ControlServer!
    var statusItem: NSStatusItem!
    var settingsWindow = SettingsWindowManager()
    let settings = AppSettings.shared

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 初始化流光窗口
        glow = GlowWindow(settings: settings)

        // 如果设置中是启用状态，自动开始
        if settings.enabled {
            glow.show()
        }

        // 启动 HTTP 控制服务
        startServer(port: settings.httpPort)

        // 端口变更时重启服务
        settings.onPortChanged = { [weak self] newPort in
            guard let self = self else { return }
            self.server.stop()
            self.startServer(port: newPort)
            FileHandle.standardError.write(Data("[edge-glow] 🔄 服务已重启 → 端口 \(newPort)\n".utf8))
        }

        // 菜单栏
        setupStatusBar()

        FileHandle.standardError.write(Data("[edge-glow] 🚀 App 启动完成\n".utf8))
    }

    private func startServer(port: Int) {
        guard port >= 1024, port <= 65535 else { return }
        server = ControlServer(port: UInt16(port))
        server.onStart = { [weak self] in self?.glow.show() }
        server.onStop  = { [weak self] in self?.glow.hide() }
        server.onPulse = { [weak self] in self?.glow.pulse() }
        server.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // 加载菜单栏图标
        let iconSize = NSSize(width: 18, height: 18)
        if let iconPath = Bundle.main.path(forResource: "menu_icon", ofType: "png"),
           let icon = NSImage(contentsOfFile: iconPath) {
            icon.size = iconSize
            icon.isTemplate = true  // 跟随系统深色/浅色模式
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "✦"
        }

        let menu = NSMenu()

        // 启用/禁用
        let enableItem = NSMenuItem(title: settings.enabled ? L("menu.enabled") : L("menu.disabled"),
                                     action: #selector(toggleEnable), keyEquivalent: "")
        enableItem.target = self
        enableItem.image = NSImage(systemSymbolName: settings.enabled ? "checkmark.circle" : "xmark.circle",
                                   accessibilityDescription: nil)
        menu.addItem(enableItem)

        menu.addItem(.separator())

        // 手动控制
        let onItem = NSMenuItem(title: L("menu.turnOn"), action: #selector(turnOn), keyEquivalent: "")
        onItem.target = self
        onItem.image = NSImage(systemSymbolName: "power.circle.fill", accessibilityDescription: nil)
        menu.addItem(onItem)

        let offItem = NSMenuItem(title: L("menu.turnOff"), action: #selector(turnOff), keyEquivalent: "")
        offItem.target = self
        offItem.image = NSImage(systemSymbolName: "power.circle", accessibilityDescription: nil)
        menu.addItem(offItem)

        menu.addItem(.separator())

        // 设置
        let settingsItem = NSMenuItem(title: L("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        // 反馈
        let feedbackItem = NSMenuItem(title: L("menu.feedback"), action: #selector(openFeedback), keyEquivalent: "")
        feedbackItem.target = self
        feedbackItem.image = NSImage(systemSymbolName: "exclamationmark.bubble", accessibilityDescription: nil)
        menu.addItem(feedbackItem)

        menu.addItem(.separator())

        // 退出
        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "arrow.right.square", accessibilityDescription: nil)
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc func toggleEnable() {
        settings.enabled.toggle()
        if let item = statusItem.menu?.items.first {
            item.title = settings.enabled ? L("menu.enabled") : L("menu.disabled")
            item.image = NSImage(systemSymbolName: settings.enabled ? "checkmark.circle" : "xmark.circle",
                                 accessibilityDescription: nil)
        }
        if settings.enabled {
            glow.show()
        } else {
            glow.hide()
        }
    }

    @objc func turnOn()  { glow.show() }
    @objc func turnOff() { glow.hide() }

    @objc func openSettings() {
        settingsWindow.show(settings: settings)
    }

    @objc func openFeedback() {
        if let url = URL(string: "https://github.com/vector4wang/EdgeGlow/issues") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

// ============================================================
// MARK: - 入口
// ============================================================
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
