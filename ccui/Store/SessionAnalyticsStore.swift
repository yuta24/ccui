import Foundation

@Observable
@MainActor
final class SessionAnalyticsStore {
    private(set) var points: [SessionAnalyticsPoint] = []
    private(set) var isLoading = false

    private let persistence: any ClaudeEventPersistence
    private var currentTask: Task<Void, Never>?

    init(persistence: any ClaudeEventPersistence = JSONFileClaudeEventPersistence()) {
        self.persistence = persistence
    }

    func load(repositoryPath: String) {
        currentTask?.cancel()
        isLoading = true
        let persistence = persistence
        currentTask = Task.detached { [weak self] in
            let points = Self.compute(persistence: persistence, repositoryPath: repositoryPath)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.points = points
                self?.isLoading = false
            }
        }
    }

    nonisolated static func compute(
        persistence: any ClaudeEventPersistence,
        repositoryPath: String
    ) -> [SessionAnalyticsPoint] {
        guard let allSessions = try? persistence.loadAll(),
              let worktreePaths = try? persistence.worktreePathsForRepository(repositoryPath)
        else { return [] }

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
