import Foundation
import OSLog

@MainActor
final class UDSListenerService {
    nonisolated static let socketPath = "/tmp/ccui.sock"
    /// 健全性チェックの間隔。socket file が他プロセスに置き換えられてから復旧までの最大遅延に相当する。
    static let healthCheckInterval: Duration = .seconds(15)

    private let socketPath: String
    private var state: ListenerState?
    private var onEvent: (@MainActor (ClaudeHookPayload) -> Void)?
    private var healthCheckTask: Task<Void, Never>?

    init(socketPath: String = UDSListenerService.socketPath) {
        self.socketPath = socketPath
    }

    func start(onEvent: @escaping @MainActor (ClaudeHookPayload) -> Void) {
        stop()
        self.onEvent = onEvent
        _ = startListener()
        startHealthCheck()
    }

    /// listener を bind/listen し、成功すれば true。
    /// 自身が作った socket file の (st_dev, st_ino) を記録しておき、後段の健全性チェックで
    /// 「filesystem 上の同名ファイルが置き換わっていないか」を識別できるようにする。
    @discardableResult
    private func startListener() -> Bool {
        Darwin.unlink(socketPath)

        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            Logger.services.error("socket() failed: \(String(cString: strerror(errno)))")
            return false
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
            return false
        }

        // Restrict socket permissions to owner only
        Darwin.chmod(socketPath, 0o600)

        guard Darwin.listen(fd, 5) == 0 else {
            Logger.services.error("listen() failed: \(String(cString: strerror(errno)))")
            Darwin.close(fd)
            return false
        }

        // Non-blocking mode to prevent accept() from blocking the main thread
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)

        let newState = ListenerState(serverFd: fd, socketPath: socketPath)
        // bind 直後の inode/dev を記録。後で stat() した結果と比較して socket 同一性を判定する。
        var st = stat()
        if Darwin.lstat(socketPath, &st) == 0 {
            newState.boundInode = st.st_ino
            newState.boundDev = st.st_dev
        }

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
        return true
    }

    private func startHealthCheck() {
        healthCheckTask?.cancel()
        let interval = Self.healthCheckInterval
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                if Task.isCancelled { return }
                self?.recoverIfStale()
            }
        }
    }

    func stop() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
        state?.shutdown()
        state = nil
        onEvent = nil
    }

    deinit {
        healthCheckTask?.cancel()
        state?.shutdown()
    }

    // MARK: - Health Check / Recovery

    /// `start()` 時に bind した socket file が今も同一 inode で存在しているか。
    /// 別プロセスが同名パスを unlink + bind した場合 false。
    /// テストや手動診断のため internal 公開。
    func isHealthy() -> Bool {
        guard let state else { return false }
        var st = stat()
        guard Darwin.lstat(socketPath, &st) == 0 else { return false }
        return st.st_ino == state.boundInode && st.st_dev == state.boundDev
    }

    /// 健全性が失われていれば再 listen する。`onEvent` ハンドラはそのまま流用する。
    /// テストや診断から手動で呼べる。
    func recoverIfStale() {
        guard onEvent != nil else { return }  // start されていない場合は何もしない
        if isHealthy() { return }
        Logger.services.warning("UDS: socket at \(self.socketPath, privacy: .public) was replaced or removed, restarting listener")
        state?.shutdown()
        state = nil
        _ = startListener()
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
nonisolated final class ListenerState: @unchecked Sendable {
    var serverFd: Int32
    var acceptSource: DispatchSourceRead?
    let socketPath: String
    /// bind 直後に stat() した socket file の inode/dev。健全性チェックで同一性判定に使う。
    var boundInode: ino_t = 0
    var boundDev: dev_t = 0

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
        // 自分の inode と異なる socket file (= 他プロセスが置き換えたもの) を巻き添えで unlink しないようにする。
        var st = stat()
        if Darwin.lstat(socketPath, &st) == 0,
           st.st_ino == boundInode,
           st.st_dev == boundDev {
            Darwin.unlink(socketPath)
        }
    }
}
