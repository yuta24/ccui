import Foundation

@Observable
@MainActor
final class ClaudeEventStore {
    private(set) var eventHistory: [String: [ClaudeEvent]] = [:]

    /// worktree パスごとの既読タイムスタンプ（この時刻以前のイベントは確認済み）
    private(set) var acknowledgedUpTo: [String: Date] = [:]

    private let listenerService = UDSListenerService()
    private var knownWorktreePaths: Set<String> = []

    private let maxHistoryPerWorktree = 50

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
        AgentState.from(events: eventHistory[worktreePath] ?? [])
    }

    /// 未読の通知/完了イベントがあるかどうか
    func hasUnacknowledged(for worktreePath: String) -> Bool {
        guard let events = eventHistory[worktreePath] else { return false }
        let cutoff = acknowledgedUpTo[worktreePath]
        return events.contains { event in
            let isTerminal = event.hookEventName == .stop
                || event.hookEventName == .notification
                || event.hookEventName == .subagentStop
            guard isTerminal else { return false }
            if let cutoff { return event.receivedAt > cutoff }
            return true
        }
    }

    var activeAgentCount: Int {
        eventHistory.keys.filter {
            let state = agentState(for: $0)
            if case .toolUse = state { return true }
            return state == .thinking
        }.count
    }

    var doneAgentCount: Int {
        eventHistory.keys.filter {
            agentState(for: $0) == .done && hasUnacknowledged(for: $0)
        }.count
    }

    var notifiedAgentCount: Int {
        eventHistory.keys.filter {
            if case .notified = agentState(for: $0) {
                return hasUnacknowledged(for: $0)
            }
            return false
        }.count
    }

    // MARK: - Mutations

    /// worktree を既読にする（履歴は保持したまま、最新イベントまでを確認済みにする）
    func acknowledge(for worktreePath: String) {
        let latest = eventHistory[worktreePath]?.last?.receivedAt ?? Date()
        acknowledgedUpTo[worktreePath] = latest
    }

    func addKnownPaths(_ paths: Set<String>) {
        knownWorktreePaths.formUnion(paths)
    }

    /// 指定パス以外を除去（リポジトリ削除時のクリーンアップ用）
    func removeKnownPathsExcept(_ paths: Set<String>) {
        knownWorktreePaths.formIntersection(paths)
        eventHistory = eventHistory.filter { paths.contains($0.key) }
        acknowledgedUpTo = acknowledgedUpTo.filter { paths.contains($0.key) }
    }

    // MARK: - Internal

    private func handle(_ payload: ClaudeHookPayload) {
        let resolvedPath = resolveWorktreePath(for: payload.cwd)
        let event = ClaudeEvent(worktreePath: resolvedPath, payload: payload)
        var list = eventHistory[resolvedPath] ?? []
        list.append(event)
        if list.count > maxHistoryPerWorktree {
            list.removeFirst()
        }
        eventHistory[resolvedPath] = list
    }

    /// cwd がサブディレクトリの場合、既知のワークツリーパスと prefix マッチする（最長マッチ優先）
    private func resolveWorktreePath(for cwd: String) -> String {
        knownWorktreePaths
            .filter { cwd == $0 || cwd.hasPrefix($0 + "/") }
            .max(by: { $0.count < $1.count })
            ?? cwd
    }
}
