import Foundation

struct ToolUsageStat: Identifiable, Sendable {
    let id: String // tool name
    let toolName: String
    let count: Int
}

struct ToolStatsSnapshot: Sendable {
    let stats: [ToolUsageStat]
    let totalEvents: Int
    let sessionCount: Int
    let interventionCount: Int
    let generatedAt: Date

    static let empty = ToolStatsSnapshot(stats: [], totalEvents: 0, sessionCount: 0, interventionCount: 0, generatedAt: Date())
}

@Observable
@MainActor
final class ToolStatsStore {
    private(set) var snapshot: ToolStatsSnapshot = .empty
    private(set) var isLoading = false

    private let persistence: any ClaudeEventPersistence
    private var currentTask: Task<Void, Never>?

    init(persistence: any ClaudeEventPersistence = JSONFileClaudeEventPersistence()) {
        self.persistence = persistence
    }

    /// ディスク上の全セッションを読み込んで統計を計算
    /// - repositoryPath: nil なら全体、指定するとそのリポジトリに属する全 worktree（削除済み含む）のみ集計
    func loadStats(repositoryPath: String? = nil) {
        currentTask?.cancel()
        isLoading = true
        let persistence = persistence
        let repoPath = repositoryPath
        currentTask = Task.detached { [weak self] in
            let snapshot = Self.computeStats(persistence: persistence, repositoryPath: repoPath)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.snapshot = snapshot
                self?.isLoading = false
            }
        }
    }

    private nonisolated static func computeStats(persistence: any ClaudeEventPersistence, repositoryPath: String?) -> ToolStatsSnapshot {
        guard let allSessions = try? persistence.loadAll() else {
            return .empty
        }

        let filteredSessions: [String: [String: AgentSession]]
        if let repoPath = repositoryPath,
           let repoPaths = try? persistence.worktreePathsForRepository(repoPath) {
            filteredSessions = allSessions.filter { repoPaths.contains($0.key) }
        } else if repositoryPath != nil {
            // リポジトリパス指定があるがインデックスにエントリがない場合は空
            filteredSessions = [:]
        } else {
            filteredSessions = allSessions
        }

        if filteredSessions.isEmpty { return .empty }

        var toolCounts: [String: Int] = [:]
        var totalEvents = 0
        var sessionCount = 0
        var interventionCount = 0

        for (_, sessions) in filteredSessions {
            for (_, session) in sessions {
                sessionCount += 1
                interventionCount += InterventionDetector.interventions(in: session.events).count
                for event in session.events {
                    totalEvents += 1
                    if event.hookEventName == .preToolUse, let toolName = event.toolName {
                        toolCounts[toolName, default: 0] += 1
                    }
                }
            }
        }

        let stats = toolCounts
            .map { ToolUsageStat(id: $0.key, toolName: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        return ToolStatsSnapshot(stats: stats, totalEvents: totalEvents, sessionCount: sessionCount, interventionCount: interventionCount, generatedAt: Date())
    }
}
