import SwiftUI

nonisolated enum AgentState: Sendable, Equatable {
    case idle
    case thinking
    case toolUse(String)
    case done
    case notified(String?)

    var displayLabel: String {
        switch self {
        case .idle: "Idle"
        case .thinking: "Thinking"
        case .toolUse(let name): name
        case .done: "Done"
        case .notified: "Notification"
        }
    }

    var systemImageName: String {
        switch self {
        case .idle: "circle"
        case .thinking: "brain"
        case .toolUse: "hammer"
        case .done: "checkmark.circle.fill"
        case .notified: "bell.fill"
        }
    }

    var color: Color {
        switch self {
        case .idle: .textTertiary
        case .thinking: .accent
        case .toolUse: .statusRenamed
        case .done: .statusClean
        case .notified: .accent
        }
    }

    /// エージェントが実行中かどうか（notified は実行中ではなくユーザーの確認待ち）
    var isActive: Bool {
        switch self {
        case .idle, .done, .notified: false
        case .thinking, .toolUse: true
        }
    }

    static func from(events: [ClaudeEvent]) -> AgentState {
        guard let last = events.last else { return .idle }
        switch last.hookEventName {
        case .preToolUse:
            return .toolUse(last.toolName ?? "Tool")
        case .postToolUse:
            return .thinking
        case .stop, .subagentStop:
            return .done
        case .notification:
            return .notified(last.message)
        case .permissionRequest:
            return .notified(last.toolName)
        case .userPromptSubmit, .sessionStart, .messageDisplay:
            return .thinking
        }
    }
}
