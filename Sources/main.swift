import Cocoa
import ServiceManagement

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
        server = ControlServer(port: UInt16(settings.httpPort))
        server.onStart = { [weak self] in self?.glow.show(mode: "thinking") }
        server.onStop  = { [weak self] in self?.glow.hide() }
        server.onPulse = { [weak self] in self?.glow.pulse() }
        server.start()

        // 检查并提示配置 Claude Code hooks
        HooksInstaller.checkAndPrompt(port: settings.httpPort)

        // 菜单栏
        setupStatusBar()

        FileHandle.standardError.write(Data("[edge-glow] 🚀 App 启动完成\n".utf8))
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
        menu.addItem(enableItem)

        menu.addItem(.separator())

        // 手动控制
        let onItem = NSMenuItem(title: L("menu.turnOn"), action: #selector(turnOn), keyEquivalent: "")
        onItem.target = self
        menu.addItem(onItem)

        let offItem = NSMenuItem(title: L("menu.turnOff"), action: #selector(turnOff), keyEquivalent: "")
        offItem.target = self
        menu.addItem(offItem)

        menu.addItem(.separator())

        // 设置
        let settingsItem = NSMenuItem(title: L("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // 反馈
        let feedbackItem = NSMenuItem(title: L("menu.feedback"), action: #selector(openFeedback), keyEquivalent: "")
        feedbackItem.target = self
        menu.addItem(feedbackItem)

        menu.addItem(.separator())

        // 退出
        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc func toggleEnable() {
        settings.enabled.toggle()
        if let item = statusItem.menu?.items.first {
            item.title = settings.enabled ? L("menu.enabled") : L("menu.disabled")
        }
        if settings.enabled {
            glow.show()
        } else {
            glow.hide()
        }
    }

    @objc func turnOn()  { glow.show(mode: "thinking") }
    @objc func turnOff() { glow.hide() }

    @objc func openSettings() {
        settingsWindow.show(settings: settings)
    }

    @objc func openFeedback() {
        if let url = URL(string: "https://github.com/yourusername/edgeglow/issues") {
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
