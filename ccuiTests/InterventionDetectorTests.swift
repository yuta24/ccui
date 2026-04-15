import Foundation
import Testing
@testable import ccui

struct InterventionDetectorTests {

    @Test func permissionRequestIsIntervention() {
        let events = [TestHelpers.makeEvent(hookEventName: .permissionRequest, toolName: "Write")]
        let result = InterventionDetector.interventions(in: events)
        #expect(result.count == 1)
    }

    @Test func userPromptSubmitIsIntervention() {
        let events = [TestHelpers.makeEvent(hookEventName: .userPromptSubmit, prompt: "fix this")]
        let result = InterventionDetector.interventions(in: events)
        #expect(result.count == 1)
    }

    @Test func askUserQuestionIsIntervention() {
        let events = [TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "AskUserQuestion")]
        let result = InterventionDetector.interventions(in: events)
        #expect(result.count == 1)
    }

    @Test func regularToolUseIsNotIntervention() {
        let events = [TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash")]
        let result = InterventionDetector.interventions(in: events)
        #expect(result.isEmpty)
    }

    @Test func postToolUseIsNotIntervention() {
        let events = [TestHelpers.makeEvent(hookEventName: .postToolUse)]
        let result = InterventionDetector.interventions(in: events)
        #expect(result.isEmpty)
    }

    @Test func stopIsNotIntervention() {
        let events = [TestHelpers.makeEvent(hookEventName: .stop)]
        let result = InterventionDetector.interventions(in: events)
        #expect(result.isEmpty)
    }

    @Test func mixedEventsFilteredCorrectly() {
        let events = [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash"),
            TestHelpers.makeEvent(hookEventName: .postToolUse),
            TestHelpers.makeEvent(hookEventName: .permissionRequest, toolName: "Write"),
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "AskUserQuestion"),
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Read"),
            TestHelpers.makeEvent(hookEventName: .userPromptSubmit),
            TestHelpers.makeEvent(hookEventName: .stop),
        ]
        let result = InterventionDetector.interventions(in: events)
        #expect(result.count == 3)
    }

    @Test func isInterventionChecksIdMembership() {
        let id1 = UUID()
        let id2 = UUID()
        let event = TestHelpers.makeEvent(id: id1)
        let interventionIds: Set<UUID> = [id1]

        #expect(InterventionDetector.isIntervention(event, interventionIds: interventionIds) == true)
        #expect(InterventionDetector.isIntervention(TestHelpers.makeEvent(id: id2), interventionIds: interventionIds) == false)
    }
}
