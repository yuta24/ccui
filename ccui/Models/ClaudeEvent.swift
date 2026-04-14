import Foundation

nonisolated struct ClaudeHookPayload: Decodable, Sendable {
    enum HookEventName: String, Codable, Sendable {
        case stop = "Stop"
        case notification = "Notification"
        case preToolUse = "PreToolUse"
        case postToolUse = "PostToolUse"
        case subagentStop = "SubagentStop"
        case permissionRequest = "PermissionRequest"
        case userPromptSubmit = "UserPromptSubmit"
    }

    let hookEventName: HookEventName
    let cwd: String
    let notificationType: String?
    let message: String?
    let isMuted: Bool?
    let toolName: String?
    let sessionId: String?
    let prompt: String?
    let toolInput: String?

    private enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case cwd
        case notificationType = "notification_type"
        case message
        case isMuted = "is_muted"
        case toolName = "tool_name"
        case sessionId = "session_id"
        case prompt
        case toolInput = "tool_input"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hookEventName = try container.decode(HookEventName.self, forKey: .hookEventName)
        cwd = try container.decode(String.self, forKey: .cwd)
        notificationType = try container.decodeIfPresent(String.self, forKey: .notificationType)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        // tool_input is an arbitrary JSON object — store as a JSON string
        if container.contains(.toolInput) {
            let raw = try container.decode(AnyCodableValue.self, forKey: .toolInput)
            let data = try JSONSerialization.data(withJSONObject: raw.value, options: [.sortedKeys])
            toolInput = String(data: data, encoding: .utf8)
        } else {
            toolInput = nil
        }
    }
}

/// Wrapper for decoding arbitrary JSON values from hook payloads.
private struct AnyCodableValue: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodableValue].self) {
            value = dict.mapValues(\.value)
        } else if let array = try? container.decode([AnyCodableValue].self) {
            value = array.map(\.value)
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }
}

nonisolated struct ClaudeEvent: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let worktreePath: String
    let sessionId: String
    let hookEventName: ClaudeHookPayload.HookEventName
    let notificationType: String?
    let message: String?
    let toolName: String?
    let prompt: String?
    let toolInput: String?
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
        self.prompt = payload.prompt
        self.toolInput = payload.toolInput
        self.receivedAt = Date()
    }

    init(id: UUID, worktreePath: String, sessionId: String, hookEventName: ClaudeHookPayload.HookEventName, notificationType: String?, message: String?, toolName: String?, prompt: String? = nil, toolInput: String? = nil, receivedAt: Date) {
        self.id = id
        self.worktreePath = worktreePath
        self.sessionId = sessionId
        self.hookEventName = hookEventName
        self.notificationType = notificationType
        self.message = message
        self.toolName = toolName
        self.prompt = prompt
        self.toolInput = toolInput
        self.receivedAt = receivedAt
    }
}
