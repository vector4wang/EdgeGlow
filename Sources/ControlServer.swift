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

    private func processRequest(_ raw: String, conn: NWConnection) {
        let path = raw.components(separatedBy: "\r\n").first?
            .split(separator: " ").dropFirst().first.map(String.init) ?? ""

        DispatchQueue.main.async { [weak self] in
            switch path {
            case "/start":
                self?.pulseTimer?.cancel()
                self?.pulseTimer = nil
                self?.onStart?()

            case "/stop":
                self?.pulseTimer?.cancel()
                self?.pulseTimer = nil
                self?.onStop?()

            case "/pulse":
                self?.pulseTimer?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    self?.onPulse?()
                }
                self?.pulseTimer = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)

            default:
                break
            }
        }

        let resp = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nAccess-Control-Allow-Origin: null\r\nConnection: close\r\n\r\nok"
        conn.send(content: Data(resp.utf8), completion: .idempotent)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { conn.cancel() }
    }
}
