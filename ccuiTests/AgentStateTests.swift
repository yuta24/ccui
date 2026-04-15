import Testing
@testable import ccui

struct AgentStateTests {

    // MARK: - from(events:)

    @Test func emptyEventsReturnsIdle() {
        let state = AgentState.from(events: [])
        #expect(state == .idle)
    }

    @Test func preToolUseReturnsToolUse() {
        let events = [TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash")]
        let state = AgentState.from(events: events)
        #expect(state == .toolUse("Bash"))
    }

    @Test func preToolUseWithoutToolNameDefaultsToTool() {
        let events = [TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: nil)]
        let state = AgentState.from(events: events)
        #expect(state == .toolUse("Tool"))
    }

    @Test func postToolUseReturnsThinking() {
        let events = [TestHelpers.makeEvent(hookEventName: .postToolUse)]
        let state = AgentState.from(events: events)
        #expect(state == .thinking)
    }

    @Test func stopReturnsDone() {
        let events = [TestHelpers.makeEvent(hookEventName: .stop)]
        let state = AgentState.from(events: events)
        #expect(state == .done)
    }

    @Test func subagentStopReturnsDone() {
        let events = [TestHelpers.makeEvent(hookEventName: .subagentStop)]
        let state = AgentState.from(events: events)
        #expect(state == .done)
    }

    @Test func notificationReturnsNotified() {
        let events = [TestHelpers.makeEvent(hookEventName: .notification, message: "hello")]
        let state = AgentState.from(events: events)
        #expect(state == .notified("hello"))
    }

    @Test func permissionRequestReturnsNotified() {
        let events = [TestHelpers.makeEvent(hookEventName: .permissionRequest, toolName: "Write")]
        let state = AgentState.from(events: events)
        #expect(state == .notified("Write"))
    }

    @Test func userPromptSubmitReturnsThinking() {
        let events = [TestHelpers.makeEvent(hookEventName: .userPromptSubmit)]
        let state = AgentState.from(events: events)
        #expect(state == .thinking)
    }

    @Test func lastEventDeterminesState() {
        let events = [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash"),
            TestHelpers.makeEvent(hookEventName: .postToolUse),
            TestHelpers.makeEvent(hookEventName: .stop),
        ]
        let state = AgentState.from(events: events)
        #expect(state == .done)
    }

    // MARK: - displayLabel

    @Test func displayLabels() {
        #expect(AgentState.idle.displayLabel == "Idle")
        #expect(AgentState.thinking.displayLabel == "Thinking")
        #expect(AgentState.toolUse("Read").displayLabel == "Read")
        #expect(AgentState.done.displayLabel == "Done")
        #expect(AgentState.notified(nil).displayLabel == "Notification")
    }

    // MARK: - isActive

    @Test func isActiveForActiveStates() {
        #expect(AgentState.thinking.isActive == true)
        #expect(AgentState.toolUse("X").isActive == true)
    }

    @Test func isActiveForInactiveStates() {
        #expect(AgentState.idle.isActive == false)
        #expect(AgentState.done.isActive == false)
        #expect(AgentState.notified(nil).isActive == false)
    }
}
