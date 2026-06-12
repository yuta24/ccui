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

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let output = Output(
                    exitCode: finished.terminationStatus,
                    standardOutput: outData,
                    standardError: errData
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
                continuation.resume(throwing: error)
                return
            }

            if let stdinPipe, let standardInput {
                stdinPipe.fileHandleForWriting.write(standardInput)
                stdinPipe.fileHandleForWriting.closeFile()
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                let claimed = resolution.withLock { current -> Bool in
                    guard current == nil else { return false }
                    current = .timedOut
                    return true
                }
                guard claimed else { return }
                if process.isRunning { process.terminate() }
                continuation.resume(throwing: RunError.timeout)
            }
        }
    }
}
