import Foundation
import os

@Observable
@MainActor
final class TerminalSessionStore {
    /// 起動直後（数秒以内）に非ゼロ終了コードでプロセスが落ちた場合に記録する、launch/resume 失敗の通知。
    struct LaunchFailure: Equatable {
        let worktreePath: String
        let sessionId: String
        let isResume: Bool
        let exitCode: Int32?
    }

    private struct ActiveSession {
        let sessionId: String
        let session: any TerminalSession
    }

    /// 起動からこの秒数以内の非ゼロ終了は launch/resume 失敗とみなす（通常終了との切り分け用）
    private static let launchFailureWindow: TimeInterval = 5

    private var sessions: [String: ActiveSession] = [:]
    private var claudePathTask: Task<String, Never>?
    private let appSettingsStore: AppSettingsStore

    private(set) var lastLaunchFailure: LaunchFailure?

    init(appSettingsStore: AppSettingsStore, eventBus: AppEventBus) {
        self.appSettingsStore = appSettingsStore
        eventBus.subscribe { [weak self] event in
            self?.handle(event)
        }
    }

    private func handle(_ event: AppEvent) {
        switch event {
        case .worktreesSynced(let allWorktreePaths):
            removeExcept(paths: allWorktreePaths)
        case .worktreeRemoved(let path):
            remove(for: path)
        case .worktreesLoaded, .repositoriesRemoved:
            break
        }
    }

    func acknowledgeLaunchFailure() {
        lastLaunchFailure = nil
    }

    /// 指定 worktree に、要求した sessionId とは別の実行中セッションが存在するか
    /// （置き換えると停止することになるため、呼び出し側で確認を挟む判断に使う）
    func hasRunningSession(for worktreePath: String, otherThan sessionId: String) -> Bool {
        guard let existing = sessions[worktreePath], existing.sessionId != sessionId else { return false }
        return existing.session.isProcessRunning
    }

    func startResolvingClaudePath() {
        claudePathTask = Task.detached(priority: .userInitiated) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "which claude"]
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
                return "claude"
            }

            // ユーザーの ~/.zshrc が重い場合に hang して ensureSession 全体を
            // ブロックしないよう、上限 10 秒でプロセスを terminate する。
            // SIGTERM をハンドルしているシェルが終了しないケースに備えて
            // さらに 2 秒待っても生きていたら SIGKILL でエスカレートする。
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
                        let resolved = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        continuation.resume(returning: resolved.isEmpty ? "claude" : resolved)
                    }
                }
            } onCancel: {
                timeoutTask.cancel()
                process.terminate()
            }
        }
    }

    func session(for worktree: Worktree) -> (any TerminalSession)? {
        sessions[worktree.path]?.session
    }

    func session(forWorktreePath path: String) -> (any TerminalSession)? {
        sessions[path]?.session
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
            // `-c` 付きは TTY があっても非対話扱いになり .zshrc が読まれないため、
            // ShellTab (`-l` のみ、TTY 経由で対話シェルになる) と環境を揃えるために `-i` を付与する。
            args: ["-i", "-l", "-c", claudeArgs],
            additionalEnvironment: appSettingsStore.resolvedEnvironmentStrings()
        )
        configureHandlers?(session)
        wrapTerminationHandlerForFailureDetection(
            session,
            worktreePath: worktree.path,
            sessionId: sessionId,
            isResume: isResume,
            launchedAt: Date()
        )
        sessions[worktree.path] = ActiveSession(sessionId: sessionId, session: session)
        return true
    }

    /// 起動直後の非ゼロ終了を launch/resume 失敗として検知し `lastLaunchFailure` に記録する。
    /// 既存の（configureHandlers が設定した）終了ハンドラはそのまま呼び出す。
    private func wrapTerminationHandlerForFailureDetection(
        _ session: any TerminalSession,
        worktreePath: String,
        sessionId: String,
        isResume: Bool,
        launchedAt: Date
    ) {
        let downstreamHandler = session.onProcessTerminated
        session.onProcessTerminated = { [weak self] (exitCode: Int32?) in
            if let exitCode, exitCode != 0,
               Date().timeIntervalSince(launchedAt) < Self.launchFailureWindow {
                self?.lastLaunchFailure = LaunchFailure(
                    worktreePath: worktreePath,
                    sessionId: sessionId,
                    isResume: isResume,
                    exitCode: exitCode
                )
            }
            downstreamHandler?(exitCode)
        }
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
