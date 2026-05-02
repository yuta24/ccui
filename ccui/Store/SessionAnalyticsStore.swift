import Foundation

@Observable
@MainActor
final class SessionAnalyticsStore {
    private(set) var points: [SessionAnalyticsPoint] = []
    private(set) var isLoading = false

    private let coordinator: ClaudeEventPersistenceCoordinator
    private var currentTask: Task<Void, Never>?

    init(persistence: any ClaudeEventPersistence = JSONFileClaudeEventPersistence()) {
        self.coordinator = ClaudeEventPersistenceCoordinator(persistence: persistence)
    }

    /// 共有 coordinator を受け取るイニシャライザ。`ClaudeEventStore` と同じ
    /// インスタンスを共有することで、書き込みと読み取りを直列化する。
    init(coordinator: ClaudeEventPersistenceCoordinator) {
        self.coordinator = coordinator
    }

    func load(repositoryPath: String) {
        currentTask?.cancel()
        isLoading = true
        let coordinator = self.coordinator
        currentTask = Task { [weak self] in
            let snapshot = try? await coordinator.loadSessionsForRepository(repositoryPath)
            guard !Task.isCancelled else { return }
            let points = await Task.detached(priority: .utility) {
                Self.compute(
                    allSessions: snapshot?.allSessions ?? [:],
                    worktreePaths: snapshot?.worktreePaths ?? []
                )
            }.value
            guard !Task.isCancelled else { return }
            self?.points = points
            self?.isLoading = false
        }
    }

    nonisolated static func compute(
        allSessions: [String: [String: AgentSession]],
        worktreePaths: Set<String>
    ) -> [SessionAnalyticsPoint] {
        return allSessions
            .filter { worktreePaths.contains($0.key) }
            .flatMap { $0.value.values }
            .compactMap { session -> SessionAnalyticsPoint? in
                guard let sessionStart = session.events.first?.receivedAt else { return nil }
                let eval = SessionEvaluation.compute(from: session)
                let toolCounts = Dictionary(
                    uniqueKeysWithValues: eval.toolStats.map { ($0.toolName, $0.count) }
                )
                return SessionAnalyticsPoint(
                    id: session.id,
                    sessionStart: sessionStart,
                    autonomyScore: eval.autonomyScore,
                    interventionCount: eval.interventionCount,
                    duration: eval.duration,
                    toolCounts: toolCounts
                )
            }
            .sorted { $0.sessionStart < $1.sessionStart }
    }
}
