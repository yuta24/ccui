import Foundation

// MARK: - Hook Level

enum HookLevel: String, CaseIterable, Identifiable, Sendable {
    case worktree = "Worktree"
    case user = "User"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .worktree: "{worktree}/.claude/settings.local.json"
        case .user: "~/.claude/settings.local.json"
        }
    }

    nonisolated func settingsPath(worktreePath: String) -> String {
        switch self {
        case .worktree:
            return (worktreePath as NSString)
                .appendingPathComponent(".claude/settings.local.json")
        case .user:
            return (NSHomeDirectory() as NSString)
                .appendingPathComponent(".claude/settings.local.json")
        }
    }
}

// MARK: - Hook Command

struct HookCommand: Identifiable, Hashable, Sendable {
    var id: UUID
    var type: String
    var command: String

    init(id: UUID = UUID(), type: String = "command", command: String = "") {
        self.id = id
        self.type = type
        self.command = command
    }
}

// MARK: - Hook Entry

struct HookEntry: Identifiable, Hashable, Sendable {
    var id: UUID
    var matcher: String
    var hooks: [HookCommand]
    let isManagedByCCUI: Bool

    init(id: UUID = UUID(), matcher: String = "", hooks: [HookCommand] = [], isManagedByCCUI: Bool = false) {
        self.id = id
        self.matcher = matcher
        self.hooks = hooks
        self.isManagedByCCUI = isManagedByCCUI
    }
}

// MARK: - Hook Fire Log

struct HookFireLog: Identifiable, Hashable, Sendable {
    let id: UUID
    let eventName: ClaudeHookPayload.HookEventName
    let toolName: String?
    let sessionId: String
    let receivedAt: Date

    init(event: ClaudeEvent) {
        self.id = event.id
        self.eventName = event.hookEventName
        self.toolName = event.toolName
        self.sessionId = event.sessionId
        self.receivedAt = event.receivedAt
    }
}
