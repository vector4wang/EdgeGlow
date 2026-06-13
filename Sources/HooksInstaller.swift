import Cocoa
import Foundation

// ============================================================
// MARK: - Hooks 配置引导（复制提示词发给 Agent，由 Agent 自动配置）
// ============================================================
class HooksInstaller {

    /// 从设置界面调用：展示引导提示词
    static func showConfigDialog(port: Int = 9876) {
        let alert = NSAlert()
        alert.messageText = L("hooks.dialog.title")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Claude Code " + L("hooks.viewConfig"))
        alert.addButton(withTitle: "Hermes Agent " + L("hooks.viewConfig"))
        alert.addButton(withTitle: L("hooks.cancel"))

        let response = alert.runModal()
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        switch index {
        case 0: showClaudeCodePrompt(port: port)
        case 1: showHermesPrompt(port: port)
        default: break
        }
    }

    // ================================================================
    // MARK: - Claude Code 引导词
    // ================================================================

    private static func showClaudeCodePrompt(port: Int) {
        let prompt = claudeCodePrompt(port: port)
        let alert = NSAlert()
        alert.messageText = L("hooks.cc.title")
        alert.informativeText = String(format: L("hooks.cc.msg"), prompt)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("hooks.cc.copy"))
        alert.addButton(withTitle: L("hooks.cc.close"))

        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt, forType: .string)
        }
    }

    /// 生成发给 Claude Code 的提示词
    private static func claudeCodePrompt(port: Int) -> String {
        let base = "http://127.0.0.1:\(port)"
        return """
        请帮我配置 EdgeGlow 的 hooks。读取 ~/.claude/settings.json，在 "hooks" 字段中添加（保留已有内容）：

        - UserPromptSubmit → curl -s \(base)/start
        - Stop → curl -s \(base)/stop

        只需要这两个 hook：用户发消息时开启流光，Claude 完成回复时关闭。
        格式：[{"hooks": [{"type": "command", "command": "curl -s <url>"}]}]
        修改完成后保存文件。
        """
    }

    // ================================================================
    // MARK: - Hermes Agent 引导词
    // ================================================================

    private static func showHermesPrompt(port: Int) {
        let prompt = hermesPrompt(port: port)
        let alert = NSAlert()
        alert.messageText = L("hooks.hermes.title")
        alert.informativeText = String(format: L("hooks.hermes.msg"), prompt)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("hooks.hermes.copy"))
        alert.addButton(withTitle: L("hooks.hermes.close"))

        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt, forType: .string)
        }
    }

    /// 生成发给 Hermes Agent 的提示词
    private static func hermesPrompt(port: Int) -> String {
        let base = "http://127.0.0.1:\(port)"
        return """
        请帮我配置 EdgeGlow 的 hooks。在 ~/.hermes/agent-hooks/ 目录下创建以下脚本（设置 chmod +x）：

        - pre_llm_call.sh → curl -s \(base)/start
        - on_session_end.sh → curl -s \(base)/stop

        每个脚本内容：#!/bin/bash\\ncurl -s <url>
        创建完成后确认。
        """
    }
}
