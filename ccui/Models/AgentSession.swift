import Foundation

nonisolated struct AgentSession: Identifiable, Sendable {
    let id: String
    let worktreePath: String
    private(set) var events: [ClaudeEvent]

    var state: AgentState {
        AgentState.from(events: events)
    }

    var lastEventAt: Date? {
        events.last?.receivedAt
    }

    var isTerminal: Bool {
        switch state {
        case .done, .idle, .notified: true
        case .thinking, .toolUse: false
        }
    }

    init(id: String, worktreePath: String, events: [ClaudeEvent] = []) {
        self.id = id
        self.worktreePath = worktreePath
        self.events = events
    }

    mutating func append(_ event: ClaudeEvent, maxEvents: Int) {
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst()
        }
    }

}

extension AgentSession: Equatable {
    nonisolated static func == (lhs: AgentSession, rhs: AgentSession) -> Bool {
        lhs.id == rhs.id && lhs.worktreePath == rhs.worktreePath && lhs.events == rhs.events
    }
}

extension AgentSession: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(worktreePath)
    }
}
