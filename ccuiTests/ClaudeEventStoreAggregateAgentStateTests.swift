import Foundation
import Testing
@testable import ccui

/// `ClaudeEventStore.aggregateSummary(from:now:acknowledgedUpTo:activeTimeout:attentionTimeout:)` の
/// 集約ロジックを直接検証する。
/// activity の優先度: runningTool > thinking > waitingForUser > unresponsive > finished > idle
/// （同種が複数あれば lastEventAt が最も新しいものを採用）。
/// attention は activity の優先順位とは独立に、未読件数と直近のものを集計する。
struct ClaudeEventStoreAggregateAgentStateTests {

    private let activeTimeout: TimeInterval = 5 * 60
    private let attentionTimeout: TimeInterval = 60 * 60

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

    private func summary(
        from sessions: [AgentSession],
        now: Date = Date(),
        acknowledgedUpTo: Date? = nil
    ) -> ClaudeEventStore.WorktreeAgentSummary {
        ClaudeEventStore.aggregateSummary(from: sessions, now: now, acknowledgedUpTo: acknowledgedUpTo, activeTimeout: activeTimeout, attentionTimeout: attentionTimeout)
    }

    // MARK: - 単一セッション

    @Test func emptyCollectionReturnsIdle() {
        let result = summary(from: [])
        #expect(result.activity == .idle)
        #expect(result.pendingAttentionCount == 0)
        #expect(result.hasUnacknowledgedFinished == false)
    }

    @Test func singleRunningToolSession() {
        let s = session(state: [.preToolUse], toolName: "Bash")
        #expect(summary(from: [s]).activity == .runningTool("Bash"))
    }

    @Test func singleThinkingSession() {
        let s = session(state: [.preToolUse, .postToolUse])
        #expect(summary(from: [s]).activity == .thinking)
    }

    @Test func singleFinishedSession() {
        let s = session(state: [.stop])
        #expect(summary(from: [s]).activity == .finished)
    }

    @Test func singleWaitingForUserSession() {
        let s = session(state: [.notification], message: "approve please")
        #expect(summary(from: [s]).activity == .waitingForUser)
    }

    @Test func singleIdleSession() {
        let s = TestHelpers.makeSession(events: [])
        #expect(summary(from: [s]).activity == .idle)
    }

    // MARK: - 優先順位

    @Test func runningToolBeatsThinking() {
        let toolUse = session(state: [.preToolUse], id: "a", toolName: "Read")
        let thinking = session(state: [.postToolUse], id: "b")
        #expect(summary(from: [thinking, toolUse]).activity == .runningTool("Read"))
    }

    @Test func runningToolBeatsWaitingForUser() {
        let toolUse = session(state: [.preToolUse], id: "a", toolName: "Edit")
        let waiting = session(state: [.notification], id: "b", message: "x")
        #expect(summary(from: [waiting, toolUse]).activity == .runningTool("Edit"))
    }

    @Test func thinkingBeatsWaitingForUser() {
        let thinking = session(state: [.postToolUse], id: "a")
        let waiting = session(state: [.notification], id: "b", message: "x")
        #expect(summary(from: [waiting, thinking]).activity == .thinking)
    }

    @Test func waitingForUserBeatsUnresponsive() {
        let base = Date()
        let waiting = session(state: [.notification], id: "a", lastEventAt: base, message: "x")
        let unresponsive = session(state: [.preToolUse], id: "b", lastEventAt: base.addingTimeInterval(-activeTimeout - 60), toolName: "Bash")
        let result = summary(from: [unresponsive, waiting], now: base)
        #expect(result.activity == .waitingForUser)
    }

    @Test func unresponsiveBeatsFinished() {
        let base = Date()
        let unresponsive = session(state: [.preToolUse], id: "a", lastEventAt: base.addingTimeInterval(-activeTimeout - 60), toolName: "Bash")
        let finished = session(state: [.stop], id: "b", lastEventAt: base)
        let result = summary(from: [finished, unresponsive], now: base)
        #expect(result.activity == .unresponsive)
    }

    @Test func finishedBeatsIdle() {
        let finished = session(state: [.stop], id: "a")
        let idle = TestHelpers.makeSession(id: "b", events: [])
        #expect(summary(from: [idle, finished]).activity == .finished)
    }

    // MARK: - 同種複数: lastEventAt 最大優先

    @Test func multipleRunningToolReturnsMostRecent() {
        let base = Date()
        let older = session(state: [.preToolUse], id: "a", lastEventAt: base, toolName: "Older")
        let newer = session(state: [.preToolUse], id: "b", lastEventAt: base.addingTimeInterval(60), toolName: "Newer")
        #expect(summary(from: [older, newer]).activity == .runningTool("Newer"))
    }

    @Test func multipleRunningToolOrderInvariant() {
        // Collection の入力順序に結果が依存しないこと
        let base = Date()
        let a = session(state: [.preToolUse], id: "a", lastEventAt: base, toolName: "A")
        let b = session(state: [.preToolUse], id: "b", lastEventAt: base.addingTimeInterval(10), toolName: "B")
        let c = session(state: [.preToolUse], id: "c", lastEventAt: base.addingTimeInterval(5), toolName: "C")
        #expect(summary(from: [a, b, c]).activity == .runningTool("B"))
        #expect(summary(from: [c, a, b]).activity == .runningTool("B"))
    }

    // MARK: - staleness によるゾンビの扱い

    @Test func staleRunningToolBecomesUnresponsiveInsteadOfDominatingForever() {
        // activeStaleness を超えてイベントが来ない toolUse セッションは unresponsive に格下げされ、
        // もう「実行中」を主張しなくなる（今回直したのと同型のバグの再発防止）
        let base = Date()
        let staleToolUse = session(state: [.preToolUse], id: "a", lastEventAt: base.addingTimeInterval(-activeTimeout - 60), toolName: "Bash")
        let finished = session(state: [.stop], id: "b", lastEventAt: base)
        let result = summary(from: [staleToolUse, finished], now: base)
        #expect(result.activity == .unresponsive)
        #expect(result.activity != .runningTool("Bash"))
    }

    // MARK: - attention の集計（activity の優先順位とは独立）

    @Test func pendingAttentionCountIsIndependentOfActivity() {
        // toolUse が activity を支配していても、別セッションの未読 attention は隠れない
        let base = Date()
        let toolUse = session(state: [.preToolUse], id: "a", lastEventAt: base, toolName: "Bash")
        let waiting = session(state: [.notification], id: "b", lastEventAt: base.addingTimeInterval(-10), message: "approve?")
        let result = summary(from: [toolUse, waiting], now: base)
        #expect(result.activity == .runningTool("Bash"))
        #expect(result.pendingAttentionCount == 1)
    }

    @Test func acknowledgedAttentionDoesNotCountAsPending() {
        let base = Date()
        let waiting = session(state: [.notification], id: "a", lastEventAt: base.addingTimeInterval(-10), message: "approve?")
        let result = summary(from: [waiting], now: base, acknowledgedUpTo: base)
        #expect(result.pendingAttentionCount == 0)
    }

    @Test func staleAttentionBeyondTimeoutIsExcluded() {
        let base = Date()
        let staleWaiting = session(state: [.notification], id: "a", lastEventAt: base.addingTimeInterval(-attentionTimeout - 60), message: "stale")
        let result = summary(from: [staleWaiting], now: base)
        #expect(result.pendingAttentionCount == 0)
    }

    @Test func multipleUnacknowledgedAttentionsAreAllCounted() {
        let base = Date()
        let older = session(state: [.notification], id: "a", lastEventAt: base.addingTimeInterval(-30), message: "first")
        let newer = session(state: [.notification], id: "b", lastEventAt: base, message: "second")
        let result = summary(from: [older, newer], now: base)
        #expect(result.pendingAttentionCount == 2)
    }

    // MARK: - hasUnacknowledgedFinished の集計

    @Test func finishedSessionWithoutAcknowledgmentSetsHasUnacknowledgedFinished() {
        let finished = session(state: [.stop], id: "a")
        let result = summary(from: [finished])
        #expect(result.hasUnacknowledgedFinished == true)
    }

    @Test func finishedSessionAcknowledgedAfterCompletionClearsHasUnacknowledgedFinished() {
        let base = Date()
        let finished = session(state: [.stop], id: "a", lastEventAt: base)
        let result = summary(from: [finished], now: base, acknowledgedUpTo: base.addingTimeInterval(60))
        #expect(result.hasUnacknowledgedFinished == false)
    }

    @Test func finishedSessionAcknowledgedBeforeCompletionKeepsHasUnacknowledgedFinished() {
        let base = Date()
        let finished = session(state: [.stop], id: "a", lastEventAt: base)
        let result = summary(from: [finished], now: base, acknowledgedUpTo: base.addingTimeInterval(-60))
        #expect(result.hasUnacknowledgedFinished == true)
    }

    // MARK: - 混在シナリオ

    @Test func mixedStatesPicksHighestPriorityActivityAndCountsAttentionSeparately() {
        let base = Date()
        let toolUse = session(state: [.preToolUse], id: "a", lastEventAt: base, toolName: "Grep")
        let thinking = session(state: [.postToolUse], id: "b", lastEventAt: base)
        let waiting = session(state: [.notification], id: "c", lastEventAt: base, message: "n")
        let finished = session(state: [.stop], id: "d", lastEventAt: base)
        let idle = TestHelpers.makeSession(id: "e", events: [])
        let result = summary(from: [idle, finished, waiting, thinking, toolUse], now: base)
        #expect(result.activity == .runningTool("Grep"))
        #expect(result.pendingAttentionCount == 1)
    }

    @Test func allIdleReturnsIdle() {
        let s1 = TestHelpers.makeSession(id: "a", events: [])
        let s2 = TestHelpers.makeSession(id: "b", events: [])
        let result = summary(from: [s1, s2])
        #expect(result.activity == .idle)
        #expect(result.pendingAttentionCount == 0)
    }
}
