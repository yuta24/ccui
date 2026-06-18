import Foundation
import os

/// コンテンツ検索に使う `rg` (ripgrep) のパスを解決し、結果をプロセス起動中キャッシュする。
/// GUI アプリは Homebrew の PATH（`/opt/homebrew/bin` 等）を継承しないため、
/// ログインシェル経由で `which rg` を実行して解決する。
actor SearchToolLocator {
    static let shared = SearchToolLocator()

    private var resolved: String??
    private var inflight: Task<String?, Never>?

    /// `rg` の絶対パスを返す。未インストールの場合は nil。
    func ripgrepPath() async -> String? {
        if let resolved {
            return resolved
        }
        if let task = inflight {
            return await task.value
        }

        let task = Task<String?, Never> {
            await Self.resolve()
        }
        inflight = task
        let path = await task.value
        inflight = nil
        resolved = path
        return path
    }

    private nonisolated static func resolve() async -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which rg"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        // パイプからの読み取りをプロセス実行中に並行して行う
        let pipeData = OSAllocatedUnfairLock<Data>(initialState: Data())
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global().async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            pipeData.withLock { $0 = data }
            readGroup.leave()
        }

        do {
            try process.run()
        } catch {
            pipe.fileHandleForReading.closeFile()
            readGroup.wait()
            return nil
        }

        // ユーザーの ~/.zshrc が重い場合に hang しないよう、上限 10 秒で
        // プロセスを terminate する。SIGTERM が効かない場合は 2 秒後に SIGKILL。
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled, process.isRunning {
                process.terminate()
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled, process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
            }
        }

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in
                    timeoutTask.cancel()
                    readGroup.wait()
                    let data = pipeData.withLock { $0 }
                    let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: (path?.isEmpty ?? true) ? nil : path)
                }
            }
        } onCancel: {
            timeoutTask.cancel()
            process.terminate()
        }
    }
}
