import SwiftUI
import Combine

// ============================================================
// MARK: - SwiftUI 设置界面
// ============================================================
struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(L("settings.title"))
                    .font(.title2.bold())
                Spacer()
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - 通用
                    sectionHeader(L("settings.general"))

                    Toggle(L("settings.enabled"), isOn: $settings.enabled)
                        .help(L("settings.enabled.help"))

                    Toggle(L("settings.autoStart"), isOn: $settings.autoStart)
                        .help(L("settings.autoStart.help"))

                    // MARK: - 外观
                    sectionHeader(L("settings.appearance"))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("settings.theme"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("Theme", selection: $settings.themeName) {
                            Text(L("theme.rainbow")).tag(ThemeName.rainbow)
                            Text(L("theme.pastel")).tag(ThemeName.pastel)
                            Text(L("theme.fire")).tag(ThemeName.fire)
                            Text(L("theme.ice")).tag(ThemeName.ice)
                        }
                        .pickerStyle(.segmented)
                    }

                    sliderRow(L("settings.speed"), value: $settings.speed, range: 1...10, format: "%.0f")
                    sliderRow(L("settings.width"), value: $settings.width, range: 1...10, format: "%.0f")
                    sliderRow(L("settings.brightness"), value: $settings.brightness, range: 0.3...1.0, format: "%.2f")

                    Picker(L("settings.direction"), selection: $settings.clockwise) {
                        Text(L("settings.clockwise")).tag(true)
                        Text(L("settings.counterCW")).tag(false)
                    }
                    .pickerStyle(.segmented)

                    // MARK: - 高级
                    sectionHeader(L("settings.advanced"))

                    HStack {
                        Text(L("settings.httpPort"))
                            .font(.subheadline)
                        Spacer()
                        TextField("", value: $settings.httpPort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    Button(L("settings.configHooks")) {
                        HooksInstaller.showConfigDialog(port: settings.httpPort)
                    }

                    Text(String(format: L("settings.hooksHint"), "http://127.0.0.1:\(settings.httpPort)"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(20)
            }
        }
        .frame(width: 380, height: 560)
    }

    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.accentColor)
    }

    private func sliderRow(_ label: String, value: Binding<Double>,
                            range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
            Slider(value: value, in: range)
        }
    }
}

// ============================================================
// MARK: - 设置窗口管理器
// ============================================================
class SettingsWindowManager {
    var window: NSWindow?
    var closeDelegate: WindowCloseDelegate?

    func show(settings: AppSettings) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView(settings: settings)
        let hostingController = NSHostingController(rootView: settingsView)

        let win = NSWindow(contentViewController: hostingController)
        win.title = "EdgeGlow"
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.center()
        win.isReleasedWhenClosed = false
        win.level = .floating

        let del = WindowCloseDelegate { [weak self] in
            self?.window = nil
            self?.closeDelegate = nil
            NSApp.setActivationPolicy(.accessory)
        }
        self.closeDelegate = del
        win.delegate = del

        window = win
        NSApp.setActivationPolicy(.regular)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

class WindowCloseDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(_ onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
