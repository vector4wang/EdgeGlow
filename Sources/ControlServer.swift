import Foundation
import Network

// ============================================================
// MARK: - HTTP 控制服务器
// ============================================================
class ControlServer {
    private var listener: NWListener?
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?
    var onPulse: (() -> Void)?
    private let port: UInt16
    private var pulseTimer: DispatchWorkItem?
    private var safetyTimer: DispatchWorkItem?

    /// 引用计数：多个 Agent 窗口同时工作时，流光不会误灭
    private var activeCount = 0 {
        didSet {
            FileHandle.standardError.write(Data("[edge-glow] 🔢 activeCount = \(activeCount)\n".utf8))
        }
    }

    init(port: UInt16 = 9876) {
        self.port = port
    }

    func start() {
        let param = NWParameters.tcp
        param.acceptLocalOnly = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            FileHandle.standardError.write(Data("[edge-glow] ❌ 无效端口: \(port)\n".utf8))
            return
        }

        do {
            listener = try NWListener(using: param, on: nwPort)
        } catch {
            FileHandle.standardError.write(Data("[edge-glow] ❌ 端口 \(port) 绑定失败: \(error)\n".utf8))
            return
        }

        listener?.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global())
            self?.handle(conn)
        }
        listener?.start(queue: .global())
        FileHandle.standardError.write(Data("[edge-glow] HTTP → http://127.0.0.1:\(port)\n".utf8))
    }

    func stop() {
        pulseTimer?.cancel()
        pulseTimer = nil
        safetyTimer?.cancel()
        safetyTimer = nil
        listener?.cancel()
        listener = nil
    }

    private func handle(_ conn: NWConnection) {
        var buffer = Data()

        func readMore() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
                if let data = data { buffer.append(data) }

                // 检查是否收到完整 HTTP 头
                if let str = String(data: buffer, encoding: .utf8), str.contains("\r\n\r\n") {
                    self?.processRequest(str, conn: conn)
                } else if isComplete || error != nil {
                    // 连接关闭或出错，尝试处理已有数据
                    if let str = String(data: buffer, encoding: .utf8), !str.isEmpty {
                        self?.processRequest(str, conn: conn)
                    } else {
                        conn.cancel()
                    }
                } else {
                    readMore()  // 继续读取
                }
            }
        }
        readMore()
    }

    private func sendResponse(_ code: Int, _ body: String, conn: NWConnection) {
        let resp = "HTTP/1.1 \(code) OK\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        conn.send(content: Data(resp.utf8), completion: .idempotent)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { conn.cancel() }
    }

    private func processRequest(_ raw: String, conn: NWConnection) {
        let firstLine = raw.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        let method = parts.first.map(String.init) ?? ""
        let path = parts.dropFirst().first.map(String.init) ?? ""

        // 只接受 GET
        guard method == "GET" || method == "OPTIONS" else {
            sendResponse(405, "Method Not Allowed", conn: conn)
            return
        }

        // OPTIONS 预检
        if method == "OPTIONS" {
            let resp = "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Methods: GET\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
            conn.send(content: Data(resp.utf8), completion: .idempotent)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { conn.cancel() }
            return
        }

        // 先执行 action，再返回响应
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch path {
            case "/start":
                self.pulseTimer?.cancel()
                self.pulseTimer = nil
                self.activeCount += 1
                self.onStart?()
                self.resetSafetyTimer()
                self.sendResponse(200, "ok", conn: conn)

            case "/stop":
                self.pulseTimer?.cancel()
                self.pulseTimer = nil
                self.activeCount = max(0, self.activeCount - 1)
                if self.activeCount == 0 { self.onStop?() }
                self.sendResponse(200, "ok", conn: conn)

            case "/pulse":
                self.pulseTimer?.cancel()
                self.activeCount = max(0, self.activeCount - 1)
                if self.activeCount == 0 {
                    self.onPulse?()
                }
                self.sendResponse(200, "ok", conn: conn)

            default:
                self.sendResponse(404, "Not Found", conn: conn)
            }
        }
    }

    /// 安全兜底：60s 无新 /start 自动归零（防止 Agent 崩溃导致计数卡住）
    private func resetSafetyTimer() {
        safetyTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.activeCount > 0 {
                FileHandle.standardError.write(Data("[edge-glow] ⏰ 60s 无活动，自动归零\n".utf8))
                self.activeCount = 0
                self.onStop?()
            }
        }
        safetyTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 60.0, execute: work)
    }
}
