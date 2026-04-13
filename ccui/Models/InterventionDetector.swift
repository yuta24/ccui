import Foundation

nonisolated enum InterventionDetector {
    static func interventions(in events: [ClaudeEvent]) -> [ClaudeEvent] {
        events.filter { event in
            switch event.hookEventName {
            case .permissionRequest:
                return true
            case .userPromptSubmit:
                return true
            case .preToolUse:
                return event.toolName == "AskUserQuestion"
            default:
                return false
            }
        }
    }

    static func isIntervention(_ event: ClaudeEvent, interventionIds: Set<UUID>) -> Bool {
        interventionIds.contains(event.id)
    }
}
