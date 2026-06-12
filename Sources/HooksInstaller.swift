import Cocoa
import Foundation

// ============================================================
// MARK: - Agent 类型
// ============================================================
enum AgentType: String, CaseIterable {
    case claudeCode = "Claude Code"
    case hermesAgent = "Hermes Agent"

    var configFile: String {
        switch self {
        case .claudeCode:  return "~/.claude/settings.json"
        case .hermesAgent: return "~/.hermes/agent-hooks/"
        }
    }

    var isInstalled: Bool {
        switch self {
        case .claudeCode:  return HooksInstaller.isClaudeCodeInstalled(port: AppSettings.shared.httpPort)
        case .hermesAgent: return HooksInstaller.isHermesInstalled(port: AppSettings.shared.httpPort)
        }
    }

    func install(port: Int) {
        switch self {
        case .claudeCode:  HooksInstaller.installClaudeCode(port: port)
        case .hermesAgent: HooksInstaller.installHermes(port: port)
        }
    }
}

// ============================================================
// MARK: - Claude Code Hooks 安装器
// ============================================================
class HooksInstaller {

    // MARK: - 启动检查

    /// 启动时调用：如果有 agent 未配置则弹窗
    static func checkAndPrompt(port: Int = 9876) {
        let unconfigured = AgentType.allCases.filter { !$0.isInstalled }
        if unconfigured.isEmpty {
            FileHandle.standardError.write(Data("[edge-glow] ✓ 所有 Agent Hooks 已配置\n".utf8))
            return
        }
        DispatchQueue.main.async { showConfigDialog(port: port) }
    }

    /// 从设置界面调用：始终弹出配置对话框
    static func showConfigDialog(port: Int = 9876) {
        let alert = NSAlert()
        alert.messageText = L("hooks.dialog.title")
        alert.informativeText = L("hooks.dialog.subtitle")
        alert.alertStyle = .informational

        for agent in AgentType.allCases {
            let status = agent.isInstalled ? L("hooks.configured") : L("hooks.notConfigured")
            alert.addButton(withTitle: "\(agent.rawValue) (\(status))")
        }
        alert.addButton(withTitle: L("hooks.cancel"))

        let response = alert.runModal()
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        if index >= 0 && index < AgentType.allCases.count {
            let agent = AgentType.allCases[index]
            if agent.isInstalled {
                let confirm = NSAlert()
                confirm.messageText = String(format: L("hooks.reconfigure.title"), agent.rawValue)
                confirm.informativeText = L("hooks.reconfigure.msg")
                confirm.alertStyle = .informational
                confirm.addButton(withTitle: L("hooks.reconfigure.btn"))
                confirm.addButton(withTitle: L("hooks.cancel"))
                if confirm.runModal() != .alertFirstButtonReturn { return }
            }
            agent.install(port: port)
        }
    }

    // ================================================================
    // MARK: - Claude Code
    // ================================================================

    private static func claudeCodeHookCommands(port: Int) -> [(event: String, url: String)] {
        let base = "http://127.0.0.1:\(port)"
        return [
            ("UserPromptSubmit",  "\(base)/start"),
            ("PreToolUse",        "\(base)/start"),
            ("PostToolUse",       "\(base)/pulse"),
            ("PermissionRequest", "\(base)/pulse"),
            ("Stop",              "\(base)/stop"),
        ]
    }

    static func isClaudeCodeInstalled(port: Int) -> Bool {
        let settingsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")

        guard let data = try? Data(contentsOf: settingsURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = obj["hooks"] as? [String: Any] else {
            return false
        }

        for (event, url) in claudeCodeHookCommands(port: port) {
            guard let entries = hooks[event] as? [[String: Any]] else { return false }
            let found = entries.contains { entry in
                guard let innerHooks = entry["hooks"] as? [[String: Any]] else { return false }
                return innerHooks.contains { hook in
                    (hook["command"] as? String)?.contains(url) == true
                }
            }
            if !found { return false }
        }
        return true
    }

    static func installClaudeCode(port: Int) {
        let settingsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")

        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = obj
        }

        var hooks = (root["hooks"] as? [String: Any]) ?? [:]

        for (event, url) in claudeCodeHookCommands(port: port) {
            let command = "curl -s \(url)"
            var eventEntries = (hooks[event] as? [[String: Any]]) ?? []

            let alreadyExists = eventEntries.contains { entry in
                guard let innerHooks = entry["hooks"] as? [[String: Any]] else { return false }
                return innerHooks.contains { hook in
                    (hook["type"] as? String) == "command" &&
                    (hook["command"] as? String)?.contains("127.0.0.1:\(port)") == true
                }
            }

            if !alreadyExists {
                eventEntries.append(["hooks": [["type": "command", "command": command]]])
                hooks[event] = eventEntries
            }
        }

        root["hooks"] = hooks
        do {
            try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
                .write(to: settingsURL, options: .atomic)
            showSuccess("Claude Code")
        } catch {
            showError("Claude Code", error)
        }
    }

    // ================================================================
    // MARK: - Hermes Agent
    // ================================================================

    /// Hermes 事件 → curl URL
    private static func hermesHookCommands(port: Int) -> [(event: String, url: String)] {
        let base = "http://127.0.0.1:\(port)"
        return [
            ("pre_llm_call",     "\(base)/start"),
            ("pre_tool_call",    "\(base)/start"),
            ("post_tool_call",   "\(base)/pulse"),
            ("on_session_end",   "\(base)/stop"),
        ]
    }

    static func isHermesInstalled(port: Int) -> Bool {
        let hooksDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hermes/agent-hooks")

        for (event, url) in hermesHookCommands(port: port) {
            let scriptPath = hooksDir.appendingPathComponent("\(event).sh")
            guard let content = try? String(contentsOf: scriptPath, encoding: .utf8) else {
                return false
            }
            if !content.contains(url) { return false }
        }
        return true
    }

    static func installHermes(port: Int) {
        let hooksDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hermes/agent-hooks")

        do {
            try FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)

            for (event, url) in hermesHookCommands(port: port) {
                let scriptPath = hooksDir.appendingPathComponent("\(event).sh")
                let script = """
                #!/bin/bash
                # EdgeGlow hook - \(event)
                curl -s \(url) > /dev/null 2>&1
                """
                try script.write(to: scriptPath, atomically: true, encoding: .utf8)

                // 设置可执行权限
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o755], ofItemAtPath: scriptPath.path
                )
            }

            showSuccess("Hermes Agent")
        } catch {
            showError("Hermes Agent", error)
        }
    }

    // ================================================================
    // MARK: - 通用提示
    // ================================================================

    private static func showSuccess(_ agentName: String) {
        let alert = NSAlert()
        alert.messageText = L("hooks.success.title")
        alert.informativeText = String(format: L("hooks.success.msg"), agentName, agentName)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("hooks.success.ok"))
        alert.runModal()
    }

    private static func showError(_ agentName: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = L("hooks.error.title")
        alert.informativeText = String(format: L("hooks.error.msg"), agentName, error.localizedDescription)
        alert.alertStyle = .critical
        alert.addButton(withTitle: L("hooks.error.ok"))
        alert.runModal()
    }

    // ================================================================
    // MARK: - Agent 配置提示词（复制给 CC）
    // ================================================================

    static func agentPrompt(port: Int) -> String {
        return """
        请帮我配置 EdgeGlow 的 Claude Code hooks。读取 ~/.claude/settings.json，在 "hooks" 字段中添加以下配置（保留已有的其他 hooks）：

        - UserPromptSubmit → curl -s http://127.0.0.1:\(port)/start
        - PreToolUse → curl -s http://127.0.0.1:\(port)/start
        - PostToolUse → curl -s http://127.0.0.1:\(port)/pulse
        - PermissionRequest → curl -s http://127.0.0.1:\(port)/pulse
        - Stop → curl -s http://127.0.0.1:\(port)/stop

        每个事件的 hooks 数组格式为：[{"hooks": [{"type": "command", "command": "curl -s <url>"}]}]
        如果该事件已有其他 hooks，请追加到数组末尾，不要覆盖。
        修改完成后保存文件。
        """
    }
}
