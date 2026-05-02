import Foundation

@Observable
@MainActor
final class TerminalSessionStore {
    private struct ActiveSession {
        let sessionId: String
        let session: any TerminalSession
    }

    private var sessions: [String: ActiveSession] = [:]
    private var claudePathTask: Task<String, Never>?
    private let appSettingsStore: AppSettingsStore

    init(appSettingsStore: AppSettingsStore) {
        self.appSettingsStore = appSettingsStore
    }

    func startResolvingClaudePath() {
        claudePathTask = Task.detached(priority: .userInitiated) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "which claude"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                return "claude"
            }

            return await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    process.terminationHandler = { _ in
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let resolved = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        continuation.resume(returning: resolved.isEmpty ? "claude" : resolved)
                    }
                }
            } onCancel: {
                process.terminate()
            }
        }
    }

    func session(for worktree: Worktree) -> (any TerminalSession)? {
        sessions[worktree.path]?.session
    }

    func currentSessionId(for worktreePath: String) -> String? {
        sessions[worktreePath]?.sessionId
    }

    /// 指定 worktree のターミナルが要求された sessionId と一致していることを保証する。
    /// 既存ターミナルが別 sessionId を実行中の場合は停止して張替える。
    ///
    /// `configureHandlers` は新しい session を生成した直後に同期的に呼ばれるため、
    /// 連続呼び出しで await を挟んでも sessionId と handler のキャプチャが食い違わない。
    ///
    /// - Returns: 新規作成または張替えで実際にターミナルが立ち上がった場合 true。
    @discardableResult
    func ensureSession(
        for worktree: Worktree,
        sessionId: String,
        isResume: Bool,
        configureHandlers: ((any TerminalSession) -> Void)? = nil
    ) async -> Bool {
        // dict 操作を同期ブロックに揃えるため、suspend point は冒頭で消化しておく
        let claudePath = await claudePathTask?.value ?? "claude"

        if let existing = sessions[worktree.path] {
            if existing.sessionId == sessionId {
                return false
            }
            detachAndTerminate(existing)
            sessions.removeValue(forKey: worktree.path)
        }
        let claudeArgs = if isResume {
            "\(claudePath) --resume \(sessionId)"
        } else {
            "\(claudePath) --session-id \(sessionId)"
        }
        let session = SwiftTermSession(
            workingDirectory: worktree.path,
            label: "Terminal",
            executable: "/bin/zsh",
            args: ["-l", "-c", claudeArgs],
            additionalEnvironment: appSettingsStore.resolvedEnvironmentStrings()
        )
        configureHandlers?(session)
        sessions[worktree.path] = ActiveSession(sessionId: sessionId, session: session)
        return true
    }

    func remove(for path: String) {
        guard let existing = sessions[path] else { return }
        detachAndTerminate(existing)
        sessions.removeValue(forKey: path)
    }

    /// 指定 sessionId が実行中の場合のみ停止する（他 ID なら no-op）
    func removeIfMatches(path: String, sessionId: String) {
        guard let existing = sessions[path], existing.sessionId == sessionId else { return }
        detachAndTerminate(existing)
        sessions.removeValue(forKey: path)
    }

    func removeExcept(paths: Set<String>) {
        let toRemove = sessions.keys.filter { !paths.contains($0) }
        for key in toRemove {
            if let existing = sessions[key] {
                detachAndTerminate(existing)
            }
            sessions.removeValue(forKey: key)
        }
    }

    func terminateAll() {
        for entry in sessions.values {
            detachAndTerminate(entry)
        }
        sessions.removeAll()
    }

    /// 明示的な停止前にコールバックを切り離す。
    /// 後続の置換 session に対して古いコールバックが誤発火するのを防ぐ。
    private func detachAndTerminate(_ entry: ActiveSession) {
        entry.session.onProcessTerminated = nil
        entry.session.onTitleChanged = nil
        entry.session.terminate()
    }
}
