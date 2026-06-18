import Foundation

// ============================================================
// MARK: - 全局日志工具
// ============================================================
func log(_ message: String) {
    FileHandle.standardError.write(Data("[edge-glow] \(message)\n".utf8))
}