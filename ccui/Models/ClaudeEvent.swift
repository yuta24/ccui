import Foundation

nonisolated struct ClaudeHookPayload: Decodable, Sendable {
    enum HookEventName: String, Decodable, Sendable {
        case stop = "Stop"
        case notification = "Notification"
        case preToolUse = "PreToolUse"
        case postToolUse = "PostToolUse"
        case subagentStop = "SubagentStop"
    }

    let hookEventName: HookEventName
    let cwd: String
    let notificationType: String?
    let message: String?
    let isMuted: Bool?
    let toolName: String?
    let sessionId: String?

    private enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case cwd
        case notificationType = "notification_type"
        case message
        case isMuted = "is_muted"
        case toolName = "tool_name"
        case sessionId = "session_id"
    }
}

nonisolated struct ClaudeEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    let worktreePath: String
    let sessionId: String
    let hookEventName: ClaudeHookPayload.HookEventName
    let notificationType: String?
    let message: String?
    let toolName: String?
    let receivedAt: Date

    nonisolated static func == (lhs: ClaudeEvent, rhs: ClaudeEvent) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    init(worktreePath: String, payload: ClaudeHookPayload) {
        self.id = UUID()
        self.worktreePath = worktreePath
        self.sessionId = payload.sessionId ?? "__anonymous__"
        self.hookEventName = payload.hookEventName
        self.notificationType = payload.notificationType
        self.message = payload.message
        self.toolName = payload.toolName
        self.receivedAt = Date()
    }
}
