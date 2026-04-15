import Foundation
@testable import ccui

enum TestHelpers {
    static func makeEvent(
        id: UUID = UUID(),
        worktreePath: String = "/tmp/test-repo",
        sessionId: String = "test-session",
        hookEventName: ClaudeHookPayload.HookEventName = .preToolUse,
        notificationType: String? = nil,
        message: String? = nil,
        toolName: String? = nil,
        prompt: String? = nil,
        toolInput: String? = nil,
        receivedAt: Date = Date()
    ) -> ClaudeEvent {
        ClaudeEvent(
            id: id,
            worktreePath: worktreePath,
            sessionId: sessionId,
            hookEventName: hookEventName,
            notificationType: notificationType,
            message: message,
            toolName: toolName,
            prompt: prompt,
            toolInput: toolInput,
            receivedAt: receivedAt
        )
    }

    static func makeSession(
        id: String = "test-session",
        worktreePath: String = "/tmp/test-repo",
        events: [ClaudeEvent] = []
    ) -> AgentSession {
        AgentSession(id: id, worktreePath: worktreePath, events: events)
    }
}
