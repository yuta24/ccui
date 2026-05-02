import Foundation
import OSLog

@Observable
@MainActor
final class ClaudeEventStore {
    /// worktree パス → (セッション ID → AgentSession)
    private(set) var sessions: [String: [String: AgentSession]] = [:]

    /// worktree パスごとの既読タイムスタンプ（この時刻以前のイベントは確認済み）
    private(set) var acknowledgedUpTo: [String: Date] = [:]

    /// ディスクからの読み込みに失敗した場合のエラーメッセージ
    private(set) var loadError: String?

    private let listenerService = UDSListenerService()
    private let persistenceCoordinator: ClaudeEventPersistenceCoordinator
    private let notificationService: NotificationService?
    private var knownWorktreePaths: Set<String> = []
    /// worktree パス → リポジトリパスのマッピング
    private var worktreeToRepository: [String: String] = [:]

    let maxEventsPerSessionLimit = 50
    private let maxSessionsPerWorktree = 20
    /// ディスク上に保持するワークツリーごとのセッション数上限
    private let maxDiskSessionsPerWorktree = 100
    /// active 状態でこの期間以上イベント更新がないセッションは stale とみなし active から除外
    private let activeStaleness: TimeInterval = 5 * 60
    /// notified 状態でこの期間以上更新がないペンディングは stale とみなし通知カウントから除外
    private let notifiedStaleness: TimeInterval = 60 * 60

    init(
        persistence: any ClaudeEventPersistence = JSONFileClaudeEventPersistence(),
        notificationService: NotificationService? = nil
    ) {
        self.persistenceCoordinator = ClaudeEventPersistenceCoordinator(persistence: persistence)
        self.notificationService = notificationService
    }

    /// 共有 `ClaudeEventPersistenceCoordinator` を受け取るイニシャライザ。
    /// `SessionAnalyticsStore` 等の他ストアと同じディスク領域を読み書きする場合に
    /// このイニシャライザを使い、index.json の更新を直列化する。
    init(
        coordinator: ClaudeEventPersistenceCoordinator,
        notificationService: NotificationService? = nil
    ) {
        self.persistenceCoordinator = coordinator
        self.notificationService = notificationService
    }

    // MARK: - Lifecycle

    func start() {
        Task {
            await loadFromDisk()
            await persistenceCoordinator.pruneOldSessions(maxPerWorktree: maxDiskSessionsPerWorktree)
            listenerService.start { [weak self] payload in
                self?.handle(payload)
            }
        }
    }

    func stop() {
        listenerService.stop()
    }

    // MARK: - Query

    func agentState(for worktreePath: String) -> AgentState {
        guard let worktreeSessions = sessions[worktreePath] else { return .idle }
        let states = worktreeSessions.values.map(\.state)

        // 優先度: toolUse > thinking > notified > done > idle
        if let toolUseSession = worktreeSessions.values
            .filter({ if case .toolUse = $0.state { return true }; return false })
            .max(by: { ($0.lastEventAt ?? .distantPast) < ($1.lastEventAt ?? .distantPast) }) {
            return toolUseSession.state
        }
        if states.contains(where: { $0 == .thinking }) { return .thinking }
        if let notifiedSession = worktreeSessions.values
            .filter({ if case .notified = $0.state { return true }; return false })
            .max(by: { ($0.lastEventAt ?? .distantPast) < ($1.lastEventAt ?? .distantPast) }) {
            return notifiedSession.state
        }
        if states.contains(where: { $0 == .done }) { return .done }
        return .idle
    }

    /// 未読の通知/完了イベントがあるかどうか
    func hasUnacknowledged(for worktreePath: String) -> Bool {
        guard let worktreeSessions = sessions[worktreePath] else { return false }
        let cutoff = acknowledgedUpTo[worktreePath]
        return worktreeSessions.values.contains { session in
            session.events.contains { event in
                let isTerminal = event.hookEventName == .stop
                    || event.hookEventName == .notification
                    || event.hookEventName == .subagentStop
                guard isTerminal else { return false }
                if let cutoff { return event.receivedAt > cutoff }
                return true
            }
        }
    }

    var activeAgentCount: Int {
        let cutoff = Date().addingTimeInterval(-activeStaleness)
        return sessions.values.flatMap(\.values).filter { session in
            guard session.state.isActive else { return false }
            guard let last = session.lastEventAt else { return false }
            return last > cutoff
        }.count
    }

    var doneAgentCount: Int {
        sessions.values.flatMap { worktreeSessions in
            worktreeSessions.values.filter { session in
                session.state == .done && isSessionUnacknowledged(session)
            }
        }.count
    }

    var notifiedAgentCount: Int {
        let cutoff = Date().addingTimeInterval(-notifiedStaleness)
        return sessions.values.flatMap { worktreeSessions in
            worktreeSessions.values.filter { session in
                guard case .notified = session.state else { return false }
                guard let last = session.lastEventAt, last > cutoff else { return false }
                return isSessionUnacknowledged(session)
            }
        }.count
    }

    // MARK: - Mutations

    /// worktree を既読にする（履歴は保持したまま、最新イベントまでを確認済みにする）
    func acknowledge(for worktreePath: String) {
        let latest = sessions[worktreePath]?.values
            .compactMap(\.lastEventAt)
            .max() ?? Date()
        acknowledgedUpTo[worktreePath] = latest
    }

    /// 既知の全 worktree を現時点で既読にする（ステータスバークリック等で呼び出す）
    func acknowledgeAll() {
        let now = Date()
        for path in sessions.keys {
            acknowledgedUpTo[path] = now
        }
    }

    func annotateSession(
        worktreePath: String,
        sessionId: String,
        outcome: SessionOutcome?,
        failureReasons: Set<FailureReason>
    ) {
        guard var worktreeSessions = sessions[worktreePath],
              var session = worktreeSessions[sessionId] else { return }
        session.setAnnotation(outcome: outcome, failureReasons: failureReasons)
        worktreeSessions[sessionId] = session
        sessions[worktreePath] = worktreeSessions

        let coordinator = persistenceCoordinator
        let repoPath = worktreeToRepository[worktreePath]
        Task { await coordinator.saveSession(session, worktreePath: worktreePath, repositoryPath: repoPath) }
    }

    func addKnownPaths(_ paths: Set<String>, repositoryPath: String) {
        knownWorktreePaths.formUnion(paths)
        for path in paths {
            worktreeToRepository[path] = repositoryPath
        }
    }

    /// 指定パス以外をメモリから除去（ディスク上のセッションデータは保持し、統計・分析に活用する）
    func removeKnownPathsExcept(_ paths: Set<String>) {
        knownWorktreePaths.formIntersection(paths)
        sessions = sessions.filter { paths.contains($0.key) }
        acknowledgedUpTo = acknowledgedUpTo.filter { paths.contains($0.key) }
        worktreeToRepository = worktreeToRepository.filter { paths.contains($0.key) }
    }

    /// リポジトリ削除時にディスクからもセッションデータを削除する
    func removeRepositorySessions(worktreePaths: Set<String>) {
        let coordinator = persistenceCoordinator
        for path in worktreePaths {
            Task { await coordinator.removeWorktree(path) }
        }
    }

    // MARK: - Internal

    private func handle(_ payload: ClaudeHookPayload) {
        let resolvedPath = resolveWorktreePath(for: payload.cwd)
        let event = ClaudeEvent(worktreePath: resolvedPath, payload: payload)
        let sid = event.sessionId

        var worktreeSessions = sessions[resolvedPath] ?? [:]
        var session = worktreeSessions[sid] ?? AgentSession(id: sid, worktreePath: resolvedPath)
        session.append(event, maxEvents: maxEventsPerSessionLimit)
        worktreeSessions[sid] = session

        if worktreeSessions.count > maxSessionsPerWorktree {
            evictTerminalSessions(&worktreeSessions, excluding: sid)
        }

        sessions[resolvedPath] = worktreeSessions

        notificationService?.dispatch(event: event)

        // addKnownPaths 前にイベントが到着した場合は保存を遅延させない（セッションデータは保存する）が、
        // repositoryPath は判明次第 updateIndex で補完される
        let coordinator = persistenceCoordinator
        let repoPath = worktreeToRepository[resolvedPath]
        Task { await coordinator.saveSession(session, worktreePath: resolvedPath, repositoryPath: repoPath) }
    }

    /// 終了済みセッションを古い順にメモリから退避（ディスク上のファイルは保持）
    private func evictTerminalSessions(_ map: inout [String: AgentSession], excluding currentSessionId: String) {
        let terminalSessions = map.values
            .filter { $0.isTerminal && $0.id != currentSessionId }
            .sorted(by: { ($0.lastEventAt ?? .distantPast) < ($1.lastEventAt ?? .distantPast) })

        var toEvict = map.count - maxSessionsPerWorktree
        for session in terminalSessions where toEvict > 0 {
            map.removeValue(forKey: session.id)
            toEvict -= 1
        }
    }

    private func isSessionUnacknowledged(_ session: AgentSession) -> Bool {
        guard let lastEvent = session.lastEventAt else { return false }
        if let cutoff = acknowledgedUpTo[session.worktreePath] {
            return lastEvent > cutoff
        }
        return true
    }

    /// cwd がサブディレクトリの場合、既知のワークツリーパスと prefix マッチする（最長マッチ優先）
    private func resolveWorktreePath(for cwd: String) -> String {
        knownWorktreePaths
            .filter { cwd == $0 || cwd.hasPrefix($0 + "/") }
            .max(by: { $0.count < $1.count })
            ?? cwd
    }

    // MARK: - Persistence

    private func loadFromDisk() async {
        do {
            var loaded = try await persistenceCoordinator.loadAll()
            // メモリ上限を適用（ディスク上は maxDiskSessionsPerWorktree 件まで保持）
            for (path, worktreeSessions) in loaded where worktreeSessions.count > maxSessionsPerWorktree {
                var mutable = worktreeSessions
                let terminalSessions = mutable.values
                    .filter(\.isTerminal)
                    .sorted(by: { ($0.lastEventAt ?? .distantPast) < ($1.lastEventAt ?? .distantPast) })
                var toEvict = mutable.count - maxSessionsPerWorktree
                for session in terminalSessions where toEvict > 0 {
                    mutable.removeValue(forKey: session.id)
                    toEvict -= 1
                }
                loaded[path] = mutable
            }
            sessions = loaded
            // 起動時点で既存セッションは全て既読扱い。ステータスバーは「このアプリ
            // セッション中に新規発生したもの」だけを積み上げる。
            let now = Date()
            for path in sessions.keys {
                acknowledgedUpTo[path] = now
            }
        } catch {
            Logger.store.error("Failed to load claude events from disk: \(error)")
            sessions = [:]
            loadError = "Failed to load session history: \(error.localizedDescription)"
        }
    }
}

