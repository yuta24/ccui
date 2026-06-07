import Foundation
import Testing
@testable import ccui

/// `ClaudeEventStore.aggregateAgentState(from:)` の優先順位ロジックを直接検証する。
/// 優先度: toolUse > thinking > notified > done > idle。
/// toolUse / notified は同種が複数あれば lastEventAt が最も新しいものの state を返す。
struct ClaudeEventStoreAggregateAgentStateTests {

    private func session(state stateEvents: [ClaudeHookPayload.HookEventName],
                         id: String = UUID().uuidString,
                         lastEventAt: Date = Date(),
                         toolName: String? = nil,
                         message: String? = nil) -> AgentSession {
        let events = stateEvents.enumerated().map { offset, name in
            TestHelpers.makeEvent(
                sessionId: id,
                hookEventName: name,
                message: message,
                toolName: toolName,
                receivedAt: lastEventAt.addingTimeInterval(TimeInterval(offset))
            )
        }
        return TestHelpers.makeSession(id: id, events: events)
    }

    // MARK: - 単一セッション

    @Test func emptyCollectionReturnsIdle() {
        let result = ClaudeEventStore.aggregateAgentState(from: [AgentSession]())
        #expect(result == .idle)
    }

    @Test func singleToolUseSession() {
        let s = session(state: [.preToolUse], toolName: "Bash")
        let result = ClaudeEventStore.aggregateAgentState(from: [s])
        #expect(result == .toolUse("Bash"))
    }

    @Test func singleThinkingSession() {
        let s = session(state: [.preToolUse, .postToolUse])
        let result = ClaudeEventStore.aggregateAgentState(from: [s])
        #expect(result == .thinking)
    }

    @Test func singleDoneSession() {
        let s = session(state: [.stop])
        let result = ClaudeEventStore.aggregateAgentState(from: [s])
        #expect(result == .done)
    }

    @Test func singleNotifiedSession() {
        let s = session(state: [.notification], message: "approve please")
        let result = ClaudeEventStore.aggregateAgentState(from: [s])
        #expect(result == .notified("approve please"))
    }

    @Test func singleIdleSession() {
        let s = TestHelpers.makeSession(events: [])
        let result = ClaudeEventStore.aggregateAgentState(from: [s])
        #expect(result == .idle)
    }

    // MARK: - 優先順位

    @Test func toolUseBeatsThinking() {
        let toolUse = session(state: [.preToolUse], id: "a", toolName: "Read")
        let thinking = session(state: [.postToolUse], id: "b")
        let result = ClaudeEventStore.aggregateAgentState(from: [thinking, toolUse])
        #expect(result == .toolUse("Read"))
    }

    @Test func toolUseBeatsNotified() {
        let toolUse = session(state: [.preToolUse], id: "a", toolName: "Edit")
        let notified = session(state: [.notification], id: "b", message: "x")
        let result = ClaudeEventStore.aggregateAgentState(from: [notified, toolUse])
        #expect(result == .toolUse("Edit"))
    }

    @Test func thinkingBeatsNotified() {
        let thinking = session(state: [.postToolUse], id: "a")
        let notified = session(state: [.notification], id: "b", message: "x")
        let result = ClaudeEventStore.aggregateAgentState(from: [notified, thinking])
        #expect(result == .thinking)
    }

    @Test func notifiedBeatsDone() {
        let notified = session(state: [.notification], id: "a", message: "y")
        let done = session(state: [.stop], id: "b")
        let result = ClaudeEventStore.aggregateAgentState(from: [done, notified])
        #expect(result == .notified("y"))
    }

    // MARK: - notifiedCutoff によるゾンビ notified の除外

    @Test func staleNotifiedIsIgnoredInFavorOfDone() {
        let base = Date()
        let staleNotified = session(state: [.notification], id: "a", lastEventAt: base.addingTimeInterval(-3600), message: "stale")
        let done = session(state: [.stop], id: "b", lastEventAt: base)
        let result = ClaudeEventStore.aggregateAgentState(from: [staleNotified, done], notifiedCutoff: base.addingTimeInterval(-60))
        #expect(result == .done)
    }

    @Test func staleNotifiedIsIgnoredInFavorOfIdle() {
        let base = Date()
        let staleNotified = session(state: [.notification], id: "a", lastEventAt: base.addingTimeInterval(-3600), message: "stale")
        let result = ClaudeEventStore.aggregateAgentState(from: [staleNotified], notifiedCutoff: base.addingTimeInterval(-60))
        #expect(result == .idle)
    }

    @Test func freshNotifiedStillBeatsDoneWithCutoff() {
        let base = Date()
        let freshNotified = session(state: [.notification], id: "a", lastEventAt: base, message: "fresh")
        let done = session(state: [.stop], id: "b", lastEventAt: base.addingTimeInterval(-10))
        let result = ClaudeEventStore.aggregateAgentState(from: [freshNotified, done], notifiedCutoff: base.addingTimeInterval(-60))
        #expect(result == .notified("fresh"))
    }

    @Test func doneBeatsIdle() {
        let done = session(state: [.stop], id: "a")
        let idle = TestHelpers.makeSession(id: "b", events: [])
        let result = ClaudeEventStore.aggregateAgentState(from: [idle, done])
        #expect(result == .done)
    }

    // MARK: - 同種複数: lastEventAt 最大優先

    @Test func multipleToolUseReturnsMostRecent() {
        let base = Date()
        let older = session(state: [.preToolUse], id: "a", lastEventAt: base, toolName: "Older")
        let newer = session(state: [.preToolUse], id: "b", lastEventAt: base.addingTimeInterval(60), toolName: "Newer")
        let result = ClaudeEventStore.aggregateAgentState(from: [older, newer])
        #expect(result == .toolUse("Newer"))
    }

    @Test func multipleNotifiedReturnsMostRecent() {
        let base = Date()
        let older = session(state: [.notification], id: "a", lastEventAt: base, message: "first")
        let newer = session(state: [.notification], id: "b", lastEventAt: base.addingTimeInterval(30), message: "second")
        let result = ClaudeEventStore.aggregateAgentState(from: [older, newer])
        #expect(result == .notified("second"))
    }

    @Test func multipleToolUseOrderInvariant() {
        // Collection の入力順序に結果が依存しないこと
        let base = Date()
        let a = session(state: [.preToolUse], id: "a", lastEventAt: base, toolName: "A")
        let b = session(state: [.preToolUse], id: "b", lastEventAt: base.addingTimeInterval(10), toolName: "B")
        let c = session(state: [.preToolUse], id: "c", lastEventAt: base.addingTimeInterval(5), toolName: "C")
        let r1 = ClaudeEventStore.aggregateAgentState(from: [a, b, c])
        let r2 = ClaudeEventStore.aggregateAgentState(from: [c, a, b])
        #expect(r1 == .toolUse("B"))
        #expect(r2 == .toolUse("B"))
    }

    // MARK: - 混在シナリオ

    @Test func mixedStatesPicksHighestPriority() {
        let toolUse = session(state: [.preToolUse], id: "a", toolName: "Grep")
        let thinking = session(state: [.postToolUse], id: "b")
        let notified = session(state: [.notification], id: "c", message: "n")
        let done = session(state: [.stop], id: "d")
        let idle = TestHelpers.makeSession(id: "e", events: [])
        let result = ClaudeEventStore.aggregateAgentState(from: [idle, done, notified, thinking, toolUse])
        #expect(result == .toolUse("Grep"))
    }

    @Test func allIdleReturnsIdle() {
        let s1 = TestHelpers.makeSession(id: "a", events: [])
        let s2 = TestHelpers.makeSession(id: "b", events: [])
        let result = ClaudeEventStore.aggregateAgentState(from: [s1, s2])
        #expect(result == .idle)
    }
}
