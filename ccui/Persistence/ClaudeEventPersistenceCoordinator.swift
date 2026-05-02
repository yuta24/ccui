import Foundation
import OSLog

/// 永続化操作を直列化し、index.json への競合書き込みおよび読み取りの不整合を防ぐ。
/// `ClaudeEventStore`（書き込み主体）と `SessionAnalyticsStore`（読み取り）が同じ
/// インスタンスを共有することで、ファイルシステム上の整合性を担保する。
actor ClaudeEventPersistenceCoordinator {
    private let persistence: any ClaudeEventPersistence

    init(persistence: any ClaudeEventPersistence = JSONFileClaudeEventPersistence()) {
        self.persistence = persistence
    }

    func loadAll() async throws -> [String: [String: AgentSession]] {
        let persistence = self.persistence
        return try await Task.detached(priority: .utility) {
            try persistence.loadAll()
        }.value
    }

    /// 単一のディスクスナップショットから全セッションと repository に紐づく
    /// worktree パスを取得する。書き込みとの間で一貫性を確保するため、
    /// 2 回のディスクアクセスを 1 回の actor hop の中で完結させる。
    func loadSessionsForRepository(_ repositoryPath: String) async throws
        -> (allSessions: [String: [String: AgentSession]], worktreePaths: Set<String>) {
        let persistence = self.persistence
        return try await Task.detached(priority: .utility) {
            let allSessions = try persistence.loadAll()
            let worktreePaths = try persistence.worktreePathsForRepository(repositoryPath)
            return (allSessions, worktreePaths)
        }.value
    }

    func saveSession(_ session: AgentSession, worktreePath: String, repositoryPath: String?) {
        do {
            try persistence.saveSession(session, worktreePath: worktreePath, repositoryPath: repositoryPath)
        } catch {
            Logger.store.error("Failed to persist session \(session.id): \(error)")
        }
    }

    func removeSession(_ sessionId: String, worktreePath: String) {
        do {
            try persistence.removeSession(sessionId, worktreePath: worktreePath)
        } catch {
            Logger.store.error("Failed to remove session \(sessionId): \(error)")
        }
    }

    func removeWorktree(_ worktreePath: String) {
        do {
            try persistence.removeWorktree(worktreePath)
        } catch {
            Logger.store.error("Failed to remove worktree \(worktreePath, privacy: .public): \(error)")
        }
    }

    func pruneOldSessions(maxPerWorktree: Int) async {
        let persistence = self.persistence
        do {
            try await Task.detached(priority: .utility) {
                try persistence.pruneOldSessions(maxPerWorktree: maxPerWorktree)
            }.value
        } catch {
            Logger.store.error("Failed to prune old sessions: \(error)")
        }
    }
}
