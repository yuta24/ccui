import Foundation
import Testing
@testable import ccui

struct SessionEvaluationTests {

    // MARK: - formattedDuration

    @Test func formattedDurationNil() {
        let eval = SessionEvaluation(
            sessionId: "s", autonomyScore: 1, toolStats: [], duration: nil,
            eventCount: 0, interventionCount: 0, interventionsByTool: [:],
            outcome: nil, failureReasons: [], isTruncated: false
        )
        #expect(eval.formattedDuration == "< 1s")
    }

    @Test func formattedDurationSeconds() {
        let eval = SessionEvaluation(
            sessionId: "s", autonomyScore: 1, toolStats: [], duration: 45,
            eventCount: 0, interventionCount: 0, interventionsByTool: [:],
            outcome: nil, failureReasons: [], isTruncated: false
        )
        #expect(eval.formattedDuration == "45s")
    }

    @Test func formattedDurationMinutes() {
        let eval = SessionEvaluation(
            sessionId: "s", autonomyScore: 1, toolStats: [], duration: 125,
            eventCount: 0, interventionCount: 0, interventionsByTool: [:],
            outcome: nil, failureReasons: [], isTruncated: false
        )
        #expect(eval.formattedDuration == "2m 5s")
    }

    @Test func formattedDurationHours() {
        let eval = SessionEvaluation(
            sessionId: "s", autonomyScore: 1, toolStats: [], duration: 3725,
            eventCount: 0, interventionCount: 0, interventionsByTool: [:],
            outcome: nil, failureReasons: [], isTruncated: false
        )
        #expect(eval.formattedDuration == "1h 2m")
    }

    // MARK: - compute

    @Test func computeFromEmptySession() {
        let session = TestHelpers.makeSession()
        let eval = SessionEvaluation.compute(from: session)
        #expect(eval.sessionId == "test-session")
        #expect(eval.autonomyScore == 1.0)
        #expect(eval.toolStats.isEmpty)
        #expect(eval.duration == nil)
        #expect(eval.eventCount == 0)
        #expect(eval.interventionCount == 0)
    }

    @Test func computeToolStats() {
        let now = Date()
        let events = [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash", receivedAt: now),
            TestHelpers.makeEvent(hookEventName: .postToolUse, receivedAt: now.addingTimeInterval(1)),
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Read", receivedAt: now.addingTimeInterval(2)),
            TestHelpers.makeEvent(hookEventName: .postToolUse, receivedAt: now.addingTimeInterval(3)),
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash", receivedAt: now.addingTimeInterval(4)),
            TestHelpers.makeEvent(hookEventName: .stop, receivedAt: now.addingTimeInterval(5)),
        ]
        let session = TestHelpers.makeSession(events: events)
        let eval = SessionEvaluation.compute(from: session)

        #expect(eval.eventCount == 6)
        #expect(eval.toolStats.count == 2)
        // Bash appears twice, sorted first
        #expect(eval.toolStats[0].toolName == "Bash")
        #expect(eval.toolStats[0].count == 2)
        #expect(eval.toolStats[1].toolName == "Read")
        #expect(eval.toolStats[1].count == 1)
    }

    @Test func computeAutonomyScoreWithInterventions() {
        let events = [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash"),
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Read"),
            TestHelpers.makeEvent(hookEventName: .permissionRequest, toolName: "Write"),
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Write"),
        ]
        let session = TestHelpers.makeSession(events: events)
        let eval = SessionEvaluation.compute(from: session)

        // totalSteps = 3 (preToolUse) + 1 (permissionRequest) = 4
        // interventions = 1 (permissionRequest)
        // autonomy = 1 - 1/4 = 0.75
        #expect(eval.autonomyScore == 0.75)
        #expect(eval.interventionCount == 1)
    }

    @Test func computeFullAutonomy() {
        let events = [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash"),
            TestHelpers.makeEvent(hookEventName: .postToolUse),
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Read"),
            TestHelpers.makeEvent(hookEventName: .stop),
        ]
        let session = TestHelpers.makeSession(events: events)
        let eval = SessionEvaluation.compute(from: session)
        #expect(eval.autonomyScore == 1.0)
        #expect(eval.interventionCount == 0)
    }

    @Test func computeDuration() {
        let now = Date()
        let events = [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash", receivedAt: now),
            TestHelpers.makeEvent(hookEventName: .stop, receivedAt: now.addingTimeInterval(120)),
        ]
        let session = TestHelpers.makeSession(events: events)
        let eval = SessionEvaluation.compute(from: session)
        #expect(eval.duration == 120)
    }

    @Test func computeDurationSingleEventIsNil() {
        let events = [TestHelpers.makeEvent(hookEventName: .stop)]
        let session = TestHelpers.makeSession(events: events)
        let eval = SessionEvaluation.compute(from: session)
        #expect(eval.duration == nil)
    }

    @Test func computeInterventionsByTool() {
        let events = [
            TestHelpers.makeEvent(hookEventName: .permissionRequest, toolName: "Write"),
            TestHelpers.makeEvent(hookEventName: .permissionRequest, toolName: "Write"),
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "AskUserQuestion"),
            TestHelpers.makeEvent(hookEventName: .userPromptSubmit),
        ]
        let session = TestHelpers.makeSession(events: events)
        let eval = SessionEvaluation.compute(from: session)

        #expect(eval.interventionsByTool["Write"] == 2)
        #expect(eval.interventionsByTool["AskUserQuestion"] == 1)
        #expect(eval.interventionsByTool["UserPromptSubmit"] == 1)
    }

    @Test func computeOutcomePassThrough() {
        var session = TestHelpers.makeSession()
        session.setAnnotation(outcome: .success, failureReasons: [])
        let eval = SessionEvaluation.compute(from: session)
        #expect(eval.outcome == .success)
        #expect(eval.failureReasons.isEmpty)
    }

    @Test func computeFailureReasonsPassThrough() {
        var session = TestHelpers.makeSession()
        session.setAnnotation(outcome: .failure, failureReasons: [.permissionDenied, .toolSelectionError])
        let eval = SessionEvaluation.compute(from: session)
        #expect(eval.outcome == .failure)
        #expect(eval.failureReasons == [.permissionDenied, .toolSelectionError])
    }

    @Test func computeIsTruncatedPassThrough() {
        var session = TestHelpers.makeSession()
        let event = TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash")
        session.append(event, maxEvents: 0)
        #expect(session.isTruncated)
        let eval = SessionEvaluation.compute(from: session)
        #expect(eval.isTruncated)
    }
}
