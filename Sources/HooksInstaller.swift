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
        switch response {
        case .alertFirstButtonReturn: showClaudeCodePrompt(port: port)
        case .alertSecondButtonReturn: showHermesPrompt(port: port)
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
        let startCmd = #"curl -s "\#(base)/start?pid=$PPID""#
        let pulseCmd = #"curl -s "\#(base)/pulse?pid=$PPID""#
        return """
        请帮我配置 EdgeGlow 的 hooks。读取 ~/.claude/settings.json，在 "hooks" 字段中添加（保留已有内容）：

        {
          "hooks": {
            "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "\(startCmd)"}]}],
            "PreToolUse":       [{"hooks": [{"type": "command", "command": "\(startCmd)"}]}],
            "PostToolUse":      [{"hooks": [{"type": "command", "command": "\(pulseCmd)"}]}],
            "Stop":             [{"hooks": [{"type": "command", "command": "\(pulseCmd)"}]}]
          }
        }

        说明：
        - $PPID 是终端进程ID，用于多窗口追踪
        - UserPromptSubmit/PreToolUse → /start 开启流光
        - PostToolUse/Stop → /pulse 闪亮后自动关闭
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
        let startCmd = #"curl -s \#(base)/start?pid=$PPID"#
        let pulseCmd = #"curl -s \#(base)/pulse?pid=$PPID"#
        return """
        请帮我配置 EdgeGlow 的 hooks。在 ~/.hermes/agent-hooks/ 目录下创建以下脚本（设置 chmod +x）：

        - pre_llm_call.sh:
          #!/bin/bash
          \(startCmd)

        - on_llm_response.sh:
          #!/bin/bash
          \(pulseCmd)

        说明：$PPID 用于多终端追踪，防止一个终端结束时误关其他终端的流光。
        创建完成后确认。
        """
    }
}
