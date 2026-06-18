import Foundation
import Network

// ============================================================
// MARK: - HTTP 控制服务器（支持多终端 PID 追踪）
// ============================================================
class ControlServer {
    private var listener: NWListener?
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?
    var onPulse: (() -> Void)?
    private let port: UInt16

    /// 活跃终端 PID 集合（多窗口并行工作时，流光不会误灭）
    private var activePIDs = Set<Int>() {
        didSet {
            log("🔢 活跃终端: \(activePIDs.sorted())")
        }
    }

    /// 安全兜底定时器：清理长时间无心跳的 PID
    private var safetyTimers = [Int: DispatchWorkItem]()

    /// PID 超时时间（秒）- 超时自动移除
    private let pidTimeout: TimeInterval = 120

    init(port: UInt16 = 9876) {
        self.port = port
    }

    func start() {
        let param = NWParameters.tcp
        param.acceptLocalOnly = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            log("❌ 无效端口: \(port)")
            return
        }

        do {
            listener = try NWListener(using: param, on: nwPort)
        } catch {
            log("❌ 端口 \(port) 绑定失败: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global())  // 后台队列，避免阻塞主线程动画
            self?.handle(conn)
        }
        listener?.start(queue: .global())
        log("HTTP → http://127.0.0.1:\(port)")
    }

    func stop() {
        safetyTimers.values.forEach { $0.cancel() }
        safetyTimers.removeAll()
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
        let statusText: String
        switch code {
        case 200: statusText = "OK"
        case 204: statusText = "No Content"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        default: statusText = "Unknown"
        }
        let resp = "HTTP/1.1 \(code) \(statusText)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        conn.send(content: Data(resp.utf8), completion: .contentProcessed({ _ in
            conn.cancel()
        }))
    }

    /// 解析 URL 参数
    private func parseQuery(_ path: String) -> (action: String, pid: Int?) {
        let parts = path.split(separator: "?", maxSplits: 1)
        let action = String(parts[0])

        guard parts.count > 1 else { return (action, nil) }

        // 解析 ?pid=1234
        let queryString = parts[1]
        let params = queryString.split(separator: "&")
        for param in params {
            let kv = param.split(separator: "=", maxSplits: 1)
            if kv.count == 2, kv[0] == "pid", let pid = Int(kv[1]) {
                return (action, pid)
            }
        }
        return (action, nil)
    }

    private func processRequest(_ raw: String, conn: NWConnection) {
        let firstLine = raw.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        let method = parts.first.map(String.init) ?? ""
        let fullPath = parts.dropFirst().first.map(String.init) ?? ""

        // 只接受 GET
        guard method == "GET" || method == "OPTIONS" else {
            sendResponse(405, "Method Not Allowed", conn: conn)
            return
        }

        // OPTIONS 预检
        if method == "OPTIONS" {
            let resp = "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Methods: GET\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
            conn.send(content: Data(resp.utf8), completion: .contentProcessed({ _ in
                conn.cancel()
            }))
            return
        }

        // 解析 action 和 pid
        let (action, pid) = parseQuery(fullPath)

        // 先执行 action，再返回响应
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch action {
            case "/start":
                if let pid = pid {
                    self.activePIDs.insert(pid)
                    self.resetSafetyTimer(for: pid)
                }
                self.onStart?()
                self.sendResponse(200, "ok", conn: conn)

            case "/stop":
                if let pid = pid {
                    self.activePIDs.remove(pid)
                    self.safetyTimers[pid]?.cancel()
                    self.safetyTimers[pid] = nil
                }
                if self.activePIDs.isEmpty {
                    self.onStop?()
                }
                self.sendResponse(200, "ok", conn: conn)

            case "/pulse":
                if let pid = pid {
                    self.activePIDs.remove(pid)
                    self.safetyTimers[pid]?.cancel()
                    self.safetyTimers[pid] = nil
                }
                if self.activePIDs.isEmpty {
                    self.onPulse?()
                }
                self.sendResponse(200, "ok", conn: conn)

            // 向后兼容：不带 pid 的旧接口
            case "/start_legacy":
                self.onStart?()
                self.sendResponse(200, "ok", conn: conn)

            case "/stop_legacy":
                self.onStop?()
                self.sendResponse(200, "ok", conn: conn)

            case "/status":
                // 返回当前状态
                let status = """
                {"active_count":\(self.activePIDs.count),"pids":\(self.activePIDs.sorted())}
                """
                self.sendResponse(200, status, conn: conn)

            default:
                self.sendResponse(404, "Not Found", conn: conn)
            }
        }
    }

    /// 为每个 PID 设置安全超时定时器（防止终端崩溃导致计数卡住）
    private func resetSafetyTimer(for pid: Int) {
        safetyTimers[pid]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.activePIDs.contains(pid) {
                log("⏰ PID \(pid) 超时 \(Int(self.pidTimeout))s，自动移除")
                self.activePIDs.remove(pid)
                if self.activePIDs.isEmpty {
                    self.onStop?()
                }
            }
        }
        safetyTimers[pid] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + pidTimeout, execute: work)
    }
}
