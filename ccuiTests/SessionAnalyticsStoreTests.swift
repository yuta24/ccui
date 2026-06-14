import Foundation
import Testing
@testable import ccui

struct SessionAnalyticsStoreTests {

    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeSession(
        id: String,
        worktreePath: String,
        startOffset: TimeInterval,
        toolNames: [String]
    ) -> AgentSession {
        let events = toolNames.enumerated().map { index, toolName in
            TestHelpers.makeEvent(
                worktreePath: worktreePath,
                sessionId: id,
                hookEventName: .preToolUse,
                toolName: toolName,
                receivedAt: baseDate.addingTimeInterval(startOffset + Double(index))
            )
        }
        return TestHelpers.makeSession(id: id, worktreePath: worktreePath, events: events)
    }

    // MARK: - Empty Input

    @Test func computeReturnsEmptyResultForEmptyInput() {
        let result = SessionAnalyticsStore.compute(allSessions: [:], worktreePaths: [])
        #expect(result.points.isEmpty)
        #expect(result.uniqueToolCount == 0)
    }

    // MARK: - Filtering

    @Test func computeFiltersSessionsByWorktreePaths() {
        let included = makeSession(id: "a", worktreePath: "/repo/wt-a", startOffset: 0, toolNames: ["Bash"])
        let excluded = makeSession(id: "b", worktreePath: "/repo/wt-b", startOffset: 10, toolNames: ["Read"])

        let allSessions: [String: [String: AgentSession]] = [
            "/repo/wt-a": ["a": included],
            "/repo/wt-b": ["b": excluded],
        ]

        let result = SessionAnalyticsStore.compute(allSessions: allSessions, worktreePaths: ["/repo/wt-a"])
        #expect(result.points.map(\.id) == ["a"])
        #expect(result.uniqueToolCount == 1)
    }

    @Test func computeExcludesSessionsWithoutEvents() {
        let empty = TestHelpers.makeSession(id: "empty", worktreePath: "/repo/wt", events: [])
        let withEvents = makeSession(id: "filled", worktreePath: "/repo/wt", startOffset: 0, toolNames: ["Bash"])

        let allSessions: [String: [String: AgentSession]] = [
            "/repo/wt": ["empty": empty, "filled": withEvents],
        ]

        let result = SessionAnalyticsStore.compute(allSessions: allSessions, worktreePaths: ["/repo/wt"])
        #expect(result.points.map(\.id) == ["filled"])
    }

    // MARK: - Sorting

    @Test func computeSortsPointsBySessionStart() {
        let later = makeSession(id: "later", worktreePath: "/repo/wt", startOffset: 100, toolNames: ["Bash"])
        let earlier = makeSession(id: "earlier", worktreePath: "/repo/wt", startOffset: 0, toolNames: ["Read"])

        let allSessions: [String: [String: AgentSession]] = [
            "/repo/wt": ["later": later, "earlier": earlier],
        ]

        let result = SessionAnalyticsStore.compute(allSessions: allSessions, worktreePaths: ["/repo/wt"])
        #expect(result.points.map(\.id) == ["earlier", "later"])
    }

    // MARK: - Tool Counts

    @Test func computeAggregatesToolCountsPerPoint() {
        let session = makeSession(id: "s", worktreePath: "/repo/wt", startOffset: 0, toolNames: ["Bash", "Bash", "Read"])

        let allSessions: [String: [String: AgentSession]] = [
            "/repo/wt": ["s": session],
        ]

        let result = SessionAnalyticsStore.compute(allSessions: allSessions, worktreePaths: ["/repo/wt"])
        #expect(result.points.count == 1)
        let point = result.points[0]
        #expect(point.toolCounts["Bash"] == 2)
        #expect(point.toolCounts["Read"] == 1)
        #expect(result.uniqueToolCount == 2)
    }

    @Test func computeUniqueToolCountAcrossMultipleSessions() {
        let s1 = makeSession(id: "s1", worktreePath: "/repo/wt", startOffset: 0, toolNames: ["Bash"])
        let s2 = makeSession(id: "s2", worktreePath: "/repo/wt", startOffset: 10, toolNames: ["Read", "Write"])

        let allSessions: [String: [String: AgentSession]] = [
            "/repo/wt": ["s1": s1, "s2": s2],
        ]

        let result = SessionAnalyticsStore.compute(allSessions: allSessions, worktreePaths: ["/repo/wt"])
        #expect(result.uniqueToolCount == 3)
    }
}
