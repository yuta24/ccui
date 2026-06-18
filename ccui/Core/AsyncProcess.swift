import Foundation
import os

/// 外部プロセスを非同期に実行するための統一プリミティブ。
/// `GitClient` の同期/非同期混在実装や `HookTestRunner` の個別タイムアウト実装を
/// この単一の API に集約する。
enum AsyncProcess {
    nonisolated struct Output: Sendable {
        let exitCode: Int32
        let standardOutput: Data
        let standardError: Data

        var stdoutString: String {
            String(data: standardOutput, encoding: .utf8) ?? ""
        }

        var stderrString: String {
            String(data: standardError, encoding: .utf8) ?? ""
        }
    }

    enum RunError: Error, Sendable {
        /// `timeout` 経過してもプロセスが終了せず、強制終了した。
        case timeout
    }

    /// `executablePath` を `arguments` で起動し、終了を待つ。
    /// `timeout` を超えても終了しない場合はプロセスを終了させ `RunError.timeout` を throw する。
    nonisolated static func run(
        _ executablePath: String,
        arguments: [String] = [],
        currentDirectory: String? = nil,
        environment: [String: String]? = nil,
        standardInput: Data? = nil,
        timeout: TimeInterval = 30
    ) async throws -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        }
        if let environment {
            process.environment = environment
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdinPipe: Pipe?
        if standardInput != nil {
            let pipe = Pipe()
            process.standardInput = pipe
            stdinPipe = pipe
        } else {
            stdinPipe = nil
        }

        // `terminationHandler` と timeout タイマーは異なるスレッドから並行に
        // 発火しうるため、どちらが先に continuation を解決するかをこの状態で
        // 排他的に決定する（先着優先・二重 resume を防ぐ）。
        enum Resolution: Sendable {
            case completed(Output)
            case timedOut
        }
        let resolution = OSAllocatedUnfairLock<Resolution?>(initialState: nil)

        // パイプからの読み取りをプロセス実行中に並行して行う。
        // terminationHandler 内で readDataToEndOfFile() を呼ぶと、
        // 出力がパイプバッファを超えた場合にプロセスが書き込みブロックし
        // デッドロック→タイムアウトになる。
        let stdoutData = OSAllocatedUnfairLock<Data>(initialState: Data())
        let stderrData = OSAllocatedUnfairLock<Data>(initialState: Data())

        let readQueue = DispatchQueue(label: "AsyncProcess.pipeRead", attributes: .concurrent)
        let readGroup = DispatchGroup()

        readGroup.enter()
        readQueue.async {
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            stdoutData.withLock { $0 = data }
            readGroup.leave()
        }
        readGroup.enter()
        readQueue.async {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            stderrData.withLock { $0 = data }
            readGroup.leave()
        }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                readGroup.wait()
                let output = Output(
                    exitCode: finished.terminationStatus,
                    standardOutput: stdoutData.withLock { $0 },
                    standardError: stderrData.withLock { $0 }
                )
                let claimed = resolution.withLock { current -> Bool in
                    guard current == nil else { return false }
                    current = .completed(output)
                    return true
                }
                if claimed {
                    continuation.resume(returning: output)
                }
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                stdoutPipe.fileHandleForReading.closeFile()
                stderrPipe.fileHandleForReading.closeFile()
                readGroup.wait()
                continuation.resume(throwing: error)
                return
            }

            if let stdinPipe, let standardInput {
                DispatchQueue.global().async {
                    stdinPipe.fileHandleForWriting.write(standardInput)
                    stdinPipe.fileHandleForWriting.closeFile()
                }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                let claimed = resolution.withLock { current -> Bool in
                    guard current == nil else { return false }
                    current = .timedOut
                    return true
                }
                guard claimed else { return }
                if process.isRunning { process.terminate() }
                stdoutPipe.fileHandleForReading.closeFile()
                stderrPipe.fileHandleForReading.closeFile()
                continuation.resume(throwing: RunError.timeout)
            }
        }
    }
}
