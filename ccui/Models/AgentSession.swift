import Foundation

nonisolated struct AgentSession: Identifiable, Codable, Sendable {
    let id: String
    let worktreePath: String
    private(set) var events: [ClaudeEvent]
    private(set) var isTruncated: Bool
    private(set) var outcome: SessionOutcome?
    private(set) var failureReasons: Set<FailureReason>

    private enum CodingKeys: String, CodingKey {
        case id, worktreePath, events, isTruncated, outcome, failureReasons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        worktreePath = try container.decode(String.self, forKey: .worktreePath)
        events = try container.decode([ClaudeEvent].self, forKey: .events)
        isTruncated = try container.decodeIfPresent(Bool.self, forKey: .isTruncated) ?? false
        let rawOutcome = try container.decodeIfPresent(String.self, forKey: .outcome)
        outcome = rawOutcome.flatMap(SessionOutcome.init(rawValue:))
        let rawReasons = try container.decodeIfPresent([String].self, forKey: .failureReasons) ?? []
        failureReasons = Set(rawReasons.compactMap(FailureReason.init(rawValue:)))
    }

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

    var interventionCount: Int {
        InterventionDetector.interventions(in: events).count
    }

    init(id: String, worktreePath: String, events: [ClaudeEvent] = []) {
        self.id = id
        self.worktreePath = worktreePath
        self.events = events
        self.isTruncated = false
        self.outcome = nil
        self.failureReasons = []
    }

    mutating func append(_ event: ClaudeEvent, maxEvents: Int) {
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst()
            isTruncated = true
        }
    }

    mutating func setAnnotation(outcome: SessionOutcome?, failureReasons: Set<FailureReason>) {
        self.outcome = outcome
        self.failureReasons = failureReasons
    }
}

extension AgentSession: Equatable {
    nonisolated static func == (lhs: AgentSession, rhs: AgentSession) -> Bool {
        lhs.id == rhs.id && lhs.worktreePath == rhs.worktreePath && lhs.events == rhs.events
            && lhs.isTruncated == rhs.isTruncated && lhs.outcome == rhs.outcome && lhs.failureReasons == rhs.failureReasons
    }
}

extension AgentSession: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(worktreePath)
    }
}
