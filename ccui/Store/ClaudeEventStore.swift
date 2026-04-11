import Foundation

@Observable
@MainActor
final class ClaudeEventStore {
    /// worktree パス → (セッション ID → AgentSession)
    private(set) var sessions: [String: [String: AgentSession]] = [:]

    /// worktree パスごとの既読タイムスタンプ（この時刻以前のイベントは確認済み）
    private(set) var acknowledgedUpTo: [String: Date] = [:]

    private let listenerService = UDSListenerService()
    private var knownWorktreePaths: Set<String> = []

    private let maxEventsPerSession = 50
    private let maxSessionsPerWorktree = 20

    // MARK: - Lifecycle

    func start() {
        listenerService.start { [weak self] payload in
            self?.handle(payload)
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
        sessions.values.flatMap(\.values).filter(\.state.isActive).count
    }

    var doneAgentCount: Int {
        sessions.values.flatMap { worktreeSessions in
            worktreeSessions.values.filter { session in
                session.state == .done && isSessionUnacknowledged(session)
            }
        }.count
    }

    var notifiedAgentCount: Int {
        sessions.values.flatMap { worktreeSessions in
            worktreeSessions.values.filter { session in
                if case .notified = session.state {
                    return isSessionUnacknowledged(session)
                }
                return false
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

    func addKnownPaths(_ paths: Set<String>) {
        knownWorktreePaths.formUnion(paths)
    }

    /// 指定パス以外を除去（リポジトリ削除時のクリーンアップ用）
    func removeKnownPathsExcept(_ paths: Set<String>) {
        knownWorktreePaths.formIntersection(paths)
        sessions = sessions.filter { paths.contains($0.key) }
        acknowledgedUpTo = acknowledgedUpTo.filter { paths.contains($0.key) }
    }

    // MARK: - Internal

    private func handle(_ payload: ClaudeHookPayload) {
        let resolvedPath = resolveWorktreePath(for: payload.cwd)
        let event = ClaudeEvent(worktreePath: resolvedPath, payload: payload)
        let sid = event.sessionId

        var worktreeSessions = sessions[resolvedPath] ?? [:]
        var session = worktreeSessions[sid] ?? AgentSession(id: sid, worktreePath: resolvedPath)
        session.append(event, maxEvents: maxEventsPerSession)
        worktreeSessions[sid] = session

        if worktreeSessions.count > maxSessionsPerWorktree {
            pruneTerminalSessions(&worktreeSessions)
        }

        sessions[resolvedPath] = worktreeSessions
    }

    /// 終了済みセッションを古い順に削除してセッション数を上限内に収める
    private func pruneTerminalSessions(_ map: inout [String: AgentSession]) {
        let terminalSessions = map.values
            .filter(\.isTerminal)
            .sorted(by: { ($0.lastEventAt ?? .distantPast) < ($1.lastEventAt ?? .distantPast) })

        var toRemove = map.count - maxSessionsPerWorktree
        for session in terminalSessions where toRemove > 0 {
            map.removeValue(forKey: session.id)
            toRemove -= 1
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
}
