import Foundation

@Observable
@MainActor
final class SessionAnalyticsStore {
    private(set) var points: [SessionAnalyticsPoint] = []
    private(set) var uniqueToolCount: Int = 0
    private(set) var isLoading = false

    private let persistence: ClaudeEventPersistence
    private var currentTask: Task<Void, Never>?

    /// `persistence` は `ClaudeEventStore` と同じインスタンスを共有することで、
    /// 書き込みと読み取りを actor 内で直列化できる。
    init(persistence: ClaudeEventPersistence = ClaudeEventPersistence()) {
        self.persistence = persistence
    }

    nonisolated struct Result: Sendable {
        let points: [SessionAnalyticsPoint]
        let uniqueToolCount: Int
    }

    func load(repositoryPath: String) {
        currentTask?.cancel()
        isLoading = true
        let persistence = self.persistence
        currentTask = Task { [weak self] in
            let snapshot = try? await persistence.loadSessionsForRepository(repositoryPath)
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .utility) {
                Self.compute(
                    allSessions: snapshot?.allSessions ?? [:],
                    worktreePaths: snapshot?.worktreePaths ?? []
                )
            }.value
            guard !Task.isCancelled else { return }
            self?.points = result.points
            self?.uniqueToolCount = result.uniqueToolCount
            self?.isLoading = false
        }
    }

    nonisolated static func compute(
        allSessions: [String: [String: AgentSession]],
        worktreePaths: Set<String>
    ) -> Result {
        let points = allSessions
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

        var tools: Set<String> = []
        for point in points {
            tools.formUnion(point.toolCounts.keys)
        }
        return Result(points: points, uniqueToolCount: tools.count)
    }
}
