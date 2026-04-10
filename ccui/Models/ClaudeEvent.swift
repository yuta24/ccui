import Foundation

nonisolated struct ClaudeHookPayload: Decodable, Sendable {
    enum HookEventName: String, Decodable, Sendable {
        case stop = "Stop"
        case notification = "Notification"
    }

    let hookEventName: HookEventName
    let cwd: String
    let notificationType: String?
    let message: String?
    let isMuted: Bool?

    private enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case cwd
        case notificationType = "notification_type"
        case message
        case isMuted = "is_muted"
    }
}

nonisolated struct ClaudeEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    let worktreePath: String
    let hookEventName: ClaudeHookPayload.HookEventName
    let notificationType: String?
    let message: String?
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
        self.hookEventName = payload.hookEventName
        self.notificationType = payload.notificationType
        self.message = payload.message
        self.receivedAt = Date()
    }
}
