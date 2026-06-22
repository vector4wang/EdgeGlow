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
                    generalSection
                    appearanceSection
                    advancedSection
                }
                .padding(20)
            }
        }
        .frame(width: 380, height: 600)
    }

    // MARK: - Sections
    private var generalSection: some View {
        Group {
            sectionHeader(L("settings.general"))

            Toggle(L("settings.enabled"), isOn: $settings.enabled)
                .help(L("settings.enabled.help"))

            Toggle(L("settings.autoStart"), isOn: $settings.autoStart)
                .disabled(!supportsLaunchAtLogin)
                .help(supportsLaunchAtLogin ? L("settings.autoStart.help") : L("settings.autoStart.unsupported"))

            if !supportsLaunchAtLogin {
                Text(L("settings.autoStart.unsupported"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var supportsLaunchAtLogin: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    private var appearanceSection: some View {
        Group {
            sectionHeader(L("settings.appearance"))

            Picker(L("settings.theme"), selection: $settings.themeName) {
                    Text(L("theme.rainbow")).tag(ThemeName.rainbow)
                    Text(L("theme.pastel")).tag(ThemeName.pastel)
                    Text(L("theme.fire")).tag(ThemeName.fire)
                    Text(L("theme.ice")).tag(ThemeName.ice)
                    Text(L("theme.iridescent")).tag(ThemeName.iridescent)
                }
                .pickerStyle(.segmented)

            sliderRow(L("settings.speed"), value: $settings.speed, range: 1...10, format: "%.0f")
            sliderRow(L("settings.width"), value: $settings.width, range: 1...20, format: "%.0f")
            sliderRow(L("settings.brightness"), value: $settings.brightness, range: 0.3...1.0, format: "%.2f")

            Picker(L("settings.direction"), selection: $settings.clockwise) {
                Text(L("settings.clockwise")).tag(true)
                Text(L("settings.counterCW")).tag(false)
            }
            .pickerStyle(.segmented)

            Picker(L("settings.mode"), selection: $settings.glowMode) {
                Text(L("mode.flow")).tag(GlowMode.flow)
                Text(L("mode.breathe")).tag(GlowMode.breathe)
            }
            .pickerStyle(.segmented)

            Picker(L("settings.frameRate"), selection: $settings.preferredFrameRate) {
                Text("30 fps").tag(30)
                Text("60 fps").tag(60)
                Text("120 fps").tag(120)
            }
            .pickerStyle(.segmented)
        }
    }

    private var advancedSection: some View {
        Group {
            sectionHeader(L("settings.advanced"))

            HStack {
                Text(L("settings.httpPort"))
                    .font(.subheadline)
                Spacer()
                PortField(port: $settings.httpPort)
            }

            Button(L("settings.configHooks")) {
                HooksInstaller.showConfigDialog(port: settings.httpPort)
            }

            Text(String(format: L("settings.hooksHint"), "http://127.0.0.1:\(settings.httpPort)"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
// MARK: - 端口输入框（防抖：仅在提交时生效）
// ============================================================
struct PortField: View {
    @Binding var port: Int
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.roundedBorder)
            .frame(width: 80)
            .focused($isFocused)
            .onAppear { text = String(port) }
            .onSubmit { commit() }
            .onChange(of: isFocused) { focused in
                if !focused { commit() }
            }
    }

    private func commit() {
        guard let value = Int(text), value >= 1024, value <= 65535 else {
            text = String(port)  // 无效输入，回滚
            return
        }
        if value != port { port = value }
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
