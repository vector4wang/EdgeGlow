import Cocoa
import UserNotifications

// ============================================================
// MARK: - App Delegate
// ============================================================
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var glow: GlowWindowManager { GlowWindowManager.shared }
    var server: ControlServer!
    var statusItem: NSStatusItem!
    var settingsWindow = SettingsWindowManager()
    let settings = AppSettings.shared

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if !granted {
                log("⚠️ 通知权限未授予，启动提示将不显示")
            }
        }

        // 流光窗口由 GlowWindowManager 按屏幕列表自动创建

        // 启动时不自动显示流光，等待 Agent 触发或用户手动开启
        // 显示启动通知提示用户
        showLaunchNotification()

        // 启动 HTTP 控制服务
        startServer(port: settings.httpPort)

        // 端口变更时重启服务
        settings.onPortChanged = { [weak self] newPort in
            guard let self = self else { return }
            self.server.stop()
            self.startServer(port: newPort)
            log("🔄 服务已重启 → 端口 \(newPort)")
        }

        // 菜单栏
        setupStatusBar()

        log("🚀 App 启动完成")
    }

    /// 显示启动通知，提示用户如何使用
    private func showLaunchNotification() {
        let content = UNMutableNotificationContent()
        content.title = L("launch.notification.title")
        content.body = L("launch.notification.body")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(identifier: "edge-glow-launch",
                                            content: content,
                                            trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                log("⚠️ 通知发送失败: \(error)")
            }
        }
    }

    /// 按系统外观加载菜单图标（深色菜单用白色，浅色菜单用黑色）
    private func menuIcon(_ name: String) -> NSImage? {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let prefix = isDark ? "dark" : "light"
        guard let path = Bundle.main.path(forResource: "\(prefix)_\(name)",
                                          ofType: "png", inDirectory: "menu_icons"),
              let image = NSImage(contentsOfFile: path) else { return nil }
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    // MARK: - NSMenuDelegate：外观切换后刷新图标
    func menuWillOpen(_ menu: NSMenu) {
        for item in menu.items {
            let tag = item.tag
            let name: String?
            switch tag {
            case 1:  name = settings.enabled ? "check" : "xmark"
            case 2:  name = "power_on"
            case 3:  name = "power_off"
            case 4:  name = "settings"
            case 5:  name = "feedback"
            case 6:  name = "quit"
            default: name = nil
            }
            if let name = name { item.image = menuIcon(name) }
        }
    }

    private func startServer(port: Int) {
        guard port >= 1024, port <= 65535 else {
            FileHandle.standardError.write(Data("[edge-glow] ❌ 端口 \(port) 无效，需在 1024-65535 之间\n".utf8))
            return
        }
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
        menu.delegate = self

        // 启用/禁用
        let enableItem = NSMenuItem(title: settings.enabled ? L("menu.enabled") : L("menu.disabled"),
                                     action: #selector(toggleEnable), keyEquivalent: "")
        enableItem.target = self
        enableItem.tag = 1
        enableItem.image = menuIcon(settings.enabled ? "check" : "xmark")
        menu.addItem(enableItem)

        menu.addItem(.separator())

        // 手动控制
        let onItem = NSMenuItem(title: L("menu.turnOn"), action: #selector(turnOn), keyEquivalent: "")
        onItem.target = self
        onItem.tag = 2
        onItem.image = menuIcon("power_on")
        menu.addItem(onItem)

        let offItem = NSMenuItem(title: L("menu.turnOff"), action: #selector(turnOff), keyEquivalent: "")
        offItem.target = self
        offItem.tag = 3
        offItem.image = menuIcon("power_off")
        menu.addItem(offItem)

        menu.addItem(.separator())

        // 设置
        let settingsItem = NSMenuItem(title: L("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.tag = 4
        settingsItem.image = menuIcon("settings")
        menu.addItem(settingsItem)

        // 反馈
        let feedbackItem = NSMenuItem(title: L("menu.feedback"), action: #selector(openFeedback), keyEquivalent: "")
        feedbackItem.target = self
        feedbackItem.tag = 5
        feedbackItem.image = menuIcon("feedback")
        menu.addItem(feedbackItem)

        menu.addItem(.separator())

        // 退出
        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.tag = 6
        quitItem.image = menuIcon("quit")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc func toggleEnable() {
        settings.enabled.toggle()
        if let item = statusItem.menu?.items.first {
            item.title = settings.enabled ? L("menu.enabled") : L("menu.disabled")
            item.image = menuIcon(settings.enabled ? "check" : "xmark")
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
