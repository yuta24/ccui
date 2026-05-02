import Foundation
import Testing
@testable import ccui

/// `UDSListenerService` のラウンドトリップ受信を検証する。`Lengthen UDS receive
/// timeout and log decode failures` (d5faf11) と `Make UDS read loop resilient
/// to EINTR and stuck clients` (9551240) のリグレッション検知を狙う。
@MainActor
@Suite(.serialized)
struct UDSListenerServiceTests {

    private func makeUniqueSocketPath() -> String {
        // /tmp/ccui-test-<uuid>.sock。sun_path は 104 文字制限があるので長すぎる prefix は避ける
        return "/tmp/ccui-t-\(UUID().uuidString.prefix(8)).sock"
    }

    private func sendPayload(to socketPath: String, _ data: Data) throws {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.EINVAL) }
        defer { Darwin.close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        withUnsafeMutableBytes(of: &addr.sun_path) { ptr in
            pathBytes.withUnsafeBytes { src in
                ptr.copyMemory(from: UnsafeRawBufferPointer(start: src.baseAddress, count: min(src.count, ptr.count)))
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }

        try data.withUnsafeBytes { buf -> Void in
            guard let base = buf.baseAddress else { return }
            var written = 0
            while written < data.count {
                let n = Darwin.write(fd, base.advanced(by: written), data.count - written)
                if n <= 0 { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
                written += n
            }
        }
        // shutdown(WR) で EOF を送り、サーバ側 read ループに終端を伝える
        Darwin.shutdown(fd, SHUT_WR)
    }

    private func waitForOnEvent(_ holder: PayloadHolder, timeoutSeconds: Double) async -> ClaudeHookPayload? {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if let p = holder.received { return p }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return holder.received
    }

    @Test func roundTripValidPayloadFiresOnEvent() async throws {
        let path = makeUniqueSocketPath()
        let service = UDSListenerService(socketPath: path)
        let holder = PayloadHolder()
        defer { service.stop() }

        service.start { payload in
            holder.received = payload
        }

        let json = """
        {"hook_event_name":"PreToolUse","cwd":"/tmp/repo","tool_name":"Bash","session_id":"sid-1"}
        """
        try sendPayload(to: path, Data(json.utf8))

        let payload = await waitForOnEvent(holder, timeoutSeconds: 2.0)
        #expect(payload != nil)
        #expect(payload?.hookEventName == .preToolUse)
        #expect(payload?.cwd == "/tmp/repo")
        #expect(payload?.toolName == "Bash")
        #expect(payload?.sessionId == "sid-1")
    }

    /// 連続して複数のクライアントが接続した場合、両方のペイロードを受信できる
    @Test func multipleClientsAreAllProcessed() async throws {
        let path = makeUniqueSocketPath()
        let service = UDSListenerService(socketPath: path)
        let holder = PayloadAccumulator()
        defer { service.stop() }

        service.start { payload in
            holder.append(payload)
        }

        for i in 0..<5 {
            let json = """
            {"hook_event_name":"Stop","cwd":"/tmp/repo","session_id":"sid-\(i)"}
            """
            try sendPayload(to: path, Data(json.utf8))
        }

        let count = await holder.waitForCount(5, timeoutSeconds: 3.0)
        #expect(count == 5)
        #expect(Set(holder.payloads.compactMap(\.sessionId)) == Set((0..<5).map { "sid-\($0)" }))
    }

    /// 不正な JSON が来てもクラッシュせず、後続の正常なペイロードは正しく処理される
    @Test func malformedPayloadDoesNotBlockSubsequentValidPayloads() async throws {
        let path = makeUniqueSocketPath()
        let service = UDSListenerService(socketPath: path)
        let holder = PayloadHolder()
        defer { service.stop() }

        service.start { payload in
            holder.received = payload
        }

        try sendPayload(to: path, Data("{not valid json".utf8))
        try await Task.sleep(for: .milliseconds(100))
        // まだ valid payload が来ていないので nil
        #expect(holder.received == nil)

        let json = """
        {"hook_event_name":"Stop","cwd":"/tmp/repo","session_id":"after-bad"}
        """
        try sendPayload(to: path, Data(json.utf8))

        let payload = await waitForOnEvent(holder, timeoutSeconds: 2.0)
        #expect(payload?.sessionId == "after-bad")
    }

    /// stop() 後はソケットファイルが削除されている (リソース解放確認)
    @Test func stopRemovesSocketFile() async throws {
        let path = makeUniqueSocketPath()
        let service = UDSListenerService(socketPath: path)

        service.start { _ in }
        #expect(FileManager.default.fileExists(atPath: path))

        service.stop()
        // unlink 完了を待つ
        try await Task.sleep(for: .milliseconds(50))
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    // MARK: - Health check / recovery

    /// start 直後は socket file が自分のものなので isHealthy() == true
    @Test func freshlyStartedListenerIsHealthy() {
        let path = makeUniqueSocketPath()
        let service = UDSListenerService(socketPath: path)
        defer { service.stop() }
        service.start { _ in }

        #expect(service.isHealthy() == true)
    }

    /// 別プロセス相当 (raw syscall) で同名パスを unlink + bind し直すと
    /// listener の isHealthy() は false になる
    @Test func detectsExternalSocketReplacement() throws {
        let path = makeUniqueSocketPath()
        let service = UDSListenerService(socketPath: path)
        defer { service.stop() }
        service.start { _ in }
        #expect(service.isHealthy() == true)

        // 外部からの "横取り" を模す: 同名パスを unlink → 新規 socket を bind
        let intruderFd = try bindStaleSocket(at: path)
        defer { Darwin.close(intruderFd) }

        #expect(service.isHealthy() == false)
    }

    /// stale 状態を recoverIfStale() が検出して再 listen し、その後の送信が届く
    @Test func recoverIfStaleRebindsAndAcceptsNewPayloads() async throws {
        let path = makeUniqueSocketPath()
        let service = UDSListenerService(socketPath: path)
        let holder = PayloadHolder()
        defer { service.stop() }
        service.start { payload in
            holder.received = payload
        }

        // 横取り socket で listener の inode を陳腐化させる
        let intruderFd = try bindStaleSocket(at: path)
        Darwin.close(intruderFd)
        Darwin.unlink(path)
        #expect(service.isHealthy() == false)

        service.recoverIfStale()

        // 復旧後は再び自分の socket になっているはず
        #expect(service.isHealthy() == true)

        // 復旧後の listener に送信して届くことを確認
        let json = """
        {"hook_event_name":"Stop","cwd":"/tmp/repo","session_id":"after-recover"}
        """
        try sendPayload(to: path, Data(json.utf8))

        let payload = await waitForOnEvent(holder, timeoutSeconds: 2.0)
        #expect(payload?.sessionId == "after-recover")
    }

    /// stop() は他人の socket file を巻き添え削除しない
    /// (元コードは無条件 unlink で、横取り後に stop すると侵入者の socket を消していた)
    @Test func stopDoesNotUnlinkSocketOwnedByAnotherProcess() throws {
        let path = makeUniqueSocketPath()
        let service = UDSListenerService(socketPath: path)
        service.start { _ in }

        // 横取り
        let intruderFd = try bindStaleSocket(at: path)
        defer {
            Darwin.close(intruderFd)
            Darwin.unlink(path)
        }

        service.stop()

        // 横取り側の socket file は残っているはず
        #expect(FileManager.default.fileExists(atPath: path))
    }

    /// 同名パスを unlink + bind して即捨てる (横取りされた壊れた socket を作る)
    private func bindStaleSocket(at socketPath: String) throws -> Int32 {
        Darwin.unlink(socketPath)
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.EINVAL) }

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
            Darwin.close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return fd
    }
}

// MARK: - Helpers

@MainActor
private final class PayloadHolder {
    var received: ClaudeHookPayload?
}

@MainActor
private final class PayloadAccumulator {
    private(set) var payloads: [ClaudeHookPayload] = []

    func append(_ p: ClaudeHookPayload) {
        payloads.append(p)
    }

    func waitForCount(_ target: Int, timeoutSeconds: Double) async -> Int {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline && payloads.count < target {
            try? await Task.sleep(for: .milliseconds(20))
        }
        return payloads.count
    }
}
