import Foundation
import OSLog

@MainActor
final class UDSListenerService {
    nonisolated static let socketPath = "/tmp/ccui.sock"

    private var state: ListenerState?
    private var onEvent: (@MainActor (ClaudeHookPayload) -> Void)?

    func start(onEvent: @escaping @MainActor (ClaudeHookPayload) -> Void) {
        stop()
        self.onEvent = onEvent

        Darwin.unlink(Self.socketPath)

        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            Logger.services.error("socket() failed: \(String(cString: strerror(errno)))")
            return
        }

        var reuse: Int32 = 1
        Darwin.setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Self.socketPath.utf8CString
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
        Darwin.chmod(Self.socketPath, 0o600)

        guard Darwin.listen(fd, 5) == 0 else {
            Logger.services.error("listen() failed: \(String(cString: strerror(errno)))")
            Darwin.close(fd)
            return
        }

        // Non-blocking mode to prevent accept() from blocking the main thread
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)

        let newState = ListenerState(serverFd: fd)

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

            Task.detached(priority: .utility) { [weak self] in
                defer { Darwin.close(clientFd) }

                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while true {
                    let n = Darwin.read(clientFd, &buffer, buffer.count)
                    if n > 0 {
                        data.append(contentsOf: buffer[..<n])
                    } else {
                        break
                    }
                }

                guard !data.isEmpty else { return }

                let decoder = JSONDecoder()
                if let payload = try? decoder.decode(ClaudeHookPayload.self, from: data) {
                    Task { @MainActor [weak self] in
                        self?.onEvent?(payload)
                    }
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

    init(serverFd: Int32) {
        self.serverFd = serverFd
    }

    func shutdown() {
        acceptSource?.cancel()
        acceptSource = nil
        if serverFd >= 0 {
            Darwin.close(serverFd)
            serverFd = -1
        }
        Darwin.unlink(UDSListenerService.socketPath)
    }
}
