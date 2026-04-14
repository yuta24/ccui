import Foundation

nonisolated struct SessionEvaluation: Sendable {
    let sessionId: String
    let autonomyScore: Double
    let toolStats: [ToolUsageStat]
    let duration: TimeInterval?
    let eventCount: Int
    let interventionCount: Int
    let interventionsByTool: [String: Int]
    let outcome: SessionOutcome?
    let failureReasons: Set<FailureReason>

    static func compute(from session: AgentSession) -> SessionEvaluation {
        let events = session.events

        // Tool usage
        var toolCounts: [String: Int] = [:]
        var preToolUseCount = 0
        for event in events {
            if event.hookEventName == .preToolUse, let name = event.toolName {
                toolCounts[name, default: 0] += 1
                preToolUseCount += 1
            }
        }
        let toolStats = toolCounts
            .map { ToolUsageStat(id: $0.key, toolName: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        // Interventions
        let interventions = InterventionDetector.interventions(in: events)
        var interventionsByTool: [String: Int] = [:]
        for event in interventions {
            let key = event.toolName ?? event.hookEventName.rawValue
            interventionsByTool[key, default: 0] += 1
        }

        // Autonomy score — denominator includes all countable steps (tool uses + permission/prompt events)
        let otherStepCount = events.filter {
            $0.hookEventName == .permissionRequest || $0.hookEventName == .userPromptSubmit
        }.count
        let totalSteps = preToolUseCount + otherStepCount
        let autonomyScore: Double = totalSteps > 0
            ? max(0, min(1, 1.0 - Double(interventions.count) / Double(totalSteps)))
            : 1.0

        // Duration
        let duration: TimeInterval?
        if let first = events.first?.receivedAt, let last = events.last?.receivedAt, first != last {
            duration = last.timeIntervalSince(first)
        } else {
            duration = nil
        }

        return SessionEvaluation(
            sessionId: session.id,
            autonomyScore: autonomyScore,
            toolStats: toolStats,
            duration: duration,
            eventCount: events.count,
            interventionCount: interventions.count,
            interventionsByTool: interventionsByTool,
            outcome: session.outcome,
            failureReasons: session.failureReasons
        )
    }
}

extension SessionEvaluation {
    var formattedDuration: String {
        guard let duration else { return "< 1s" }
        if duration < 60 {
            return "\(Int(duration))s"
        } else if duration < 3600 {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
}
