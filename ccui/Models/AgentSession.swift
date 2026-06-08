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

    var lastEventAt: Date? {
        events.last?.receivedAt
    }

    /// ある時点 `now` における activity と attention を1回の走査でまとめて確定する。
    /// staleness 判定はここに集約し、呼び出し側で個別に staleness を比較しないようにする。
    func snapshot(now: Date, acknowledgedUpTo: Date?, activeTimeout: TimeInterval, attentionTimeout: TimeInterval) -> SessionStateSnapshot {
        SessionStateSnapshot(
            activity: activity(now: now, activeTimeout: activeTimeout),
            attention: attention(now: now, acknowledgedUpTo: acknowledgedUpTo, attentionTimeout: attentionTimeout)
        )
    }

    /// これ以上 activity が進展せず、メモリからの退避対象になりうるかどうか
    func isTerminal(now: Date, activeTimeout: TimeInterval) -> Bool {
        activity(now: now, activeTimeout: activeTimeout).isTerminal
    }

    private func activity(now: Date, activeTimeout: TimeInterval) -> SessionActivity {
        guard let last = events.last else { return .idle }

        let raw: SessionActivity
        switch last.hookEventName {
        case .preToolUse: raw = .runningTool(last.toolName ?? "Tool")
        case .postToolUse, .userPromptSubmit, .sessionStart, .messageDisplay: raw = .thinking
        case .stop, .subagentStop: raw = .finished
        case .notification, .permissionRequest: raw = .waitingForUser
        }

        guard raw.isActive, let lastEventAt else { return raw }
        if now.timeIntervalSince(lastEventAt) > activeTimeout {
            return .unresponsive
        }
        return raw
    }

    /// 直近の notification / permissionRequest イベントを探し、`events.last` が何であっても
    /// それとは独立に attention を確定する（エージェントが活動を再開しても消えないようにするため）。
    private func attention(now: Date, acknowledgedUpTo: Date?, attentionTimeout: TimeInterval) -> SessionAttention? {
        guard let event = events.last(where: { $0.hookEventName == .notification || $0.hookEventName == .permissionRequest }) else {
            return nil
        }
        guard now.timeIntervalSince(event.receivedAt) <= attentionTimeout else { return nil }

        let reason: SessionAttention.Reason = switch event.hookEventName {
        case .permissionRequest: .permissionRequest(tool: event.toolName)
        default: .notification(message: event.message)
        }
        let isAcknowledged = acknowledgedUpTo.map { event.receivedAt <= $0 } ?? false
        return SessionAttention(reason: reason, occurredAt: event.receivedAt, isAcknowledged: isAcknowledged)
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
