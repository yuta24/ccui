import Foundation
import OSLog

@MainActor
final class UDSListenerService {
    nonisolated static let socketPath = "/tmp/ccui.sock"

    private let socketPath: String
    private var state: ListenerState?
    private var onEvent: (@MainActor (ClaudeHookPayload) -> Void)?

    init(socketPath: String = UDSListenerService.socketPath) {
        self.socketPath = socketPath
    }

    func start(onEvent: @escaping @MainActor (ClaudeHookPayload) -> Void) {
        stop()
        self.onEvent = onEvent

        Darwin.unlink(socketPath)

        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            Logger.services.error("socket() failed: \(String(cString: strerror(errno)))")
            return
        }

        var reuse: Int32 = 1
        Darwin.setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        withUnsafeMutableBytes(of: &addr.sun_path) { ptr in
            pathBytes.withUnsafeBytes { src in
                ptr.copyMemory(from: UnsafeRawBufferPointer(start: src.baseAddress, count: min(src.count, ptr.count)))
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.bind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            Logger.services.error("bind() failed: \(String(cString: strerror(errno)))")
            Darwin.close(fd)
            return
        }

        // Restrict socket permissions to owner only
        Darwin.chmod(socketPath, 0o600)

        guard Darwin.listen(fd, 5) == 0 else {
            Logger.services.error("listen() failed: \(String(cString: strerror(errno)))")
            Darwin.close(fd)
            return
        }

        // Non-blocking mode to prevent accept() from blocking the main thread
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)

        let newState = ListenerState(serverFd: fd, socketPath: socketPath)

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in
            // Already on main queue; acceptConnection uses non-blocking accept
            MainActor.assumeIsolated {
                self?.acceptConnection(serverFd: fd)
            }
        }
        source.resume()
        newState.acceptSource = source

        state = newState
    }

    func stop() {
        state?.shutdown()
        state = nil
        onEvent = nil
    }

    deinit {
        state?.shutdown()
    }

    // MARK: - Connection Handling

    private func acceptConnection(serverFd: Int32) {
        // Accept all pending connections (non-blocking socket returns EWOULDBLOCK when done)
        while true {
            var clientAddr = sockaddr_un()
            var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    Darwin.accept(serverFd, sockaddrPtr, &clientLen)
                }
            }
            guard clientFd >= 0 else { break }

            // フックスクリプトが close せずに hang した場合に detached Task が
            // 蓄積するのを防ぐため、クライアント側にも受信タイムアウトを設定する。
            // SO_RCVTIMEO は read() 1 回ごとの待機時間に対してかかるため、大きい
            // ペイロードの分割受信を打ち切らないよう余裕を持たせる（30 秒）。
            var timeout = timeval(tv_sec: 30, tv_usec: 0)
            _ = Darwin.setsockopt(
                clientFd,
                SOL_SOCKET,
                SO_RCVTIMEO,
                &timeout,
                socklen_t(MemoryLayout<timeval>.size)
            )

            Task.detached(priority: .utility) { [weak self] in
                defer { Darwin.close(clientFd) }

                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                readLoop: while true {
                    let n = Darwin.read(clientFd, &buffer, buffer.count)
                    if n > 0 {
                        data.append(contentsOf: buffer[..<n])
                    } else if n == 0 {
                        break  // EOF: フック側が close した
                    } else {
                        // n == -1: errno を確認してリトライ可能なケースのみ continue
                        switch errno {
                        case EINTR:
                            // シグナル割り込み: 受信途中でドロップしないようリトライ
                            continue
                        case EAGAIN, EWOULDBLOCK:
                            // SO_RCVTIMEO 経過。これ以上のデータは来ない前提で抜ける
                            break readLoop
                        default:
                            break readLoop
                        }
                    }
                }

                guard !data.isEmpty else { return }

                let decoder = JSONDecoder()
                do {
                    let payload = try decoder.decode(ClaudeHookPayload.self, from: data)
                    Task { @MainActor [weak self] in
                        self?.onEvent?(payload)
                    }
                } catch {
                    // タイムアウト等で受信が途中で切れて不完全 JSON になった場合に
                    // サイレントドロップせず原因をログに残す。
                    Logger.services.warning("UDS: failed to decode payload (\(data.count) bytes): \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Listener State

/// Holds the server file descriptor and accept source in a sendable container
/// so `deinit` can safely clean up from outside the MainActor.
private final class ListenerState: @unchecked Sendable {
    var serverFd: Int32
    var acceptSource: DispatchSourceRead?
    let socketPath: String

    init(serverFd: Int32, socketPath: String) {
        self.serverFd = serverFd
        self.socketPath = socketPath
    }

    func shutdown() {
        acceptSource?.cancel()
        acceptSource = nil
        if serverFd >= 0 {
            Darwin.close(serverFd)
            serverFd = -1
        }
        Darwin.unlink(socketPath)
    }
}
