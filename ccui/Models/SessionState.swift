import SwiftUI

/// セッションが「今何をしているか」。`AgentState` の活動部分を引き継ぐが、
/// notification/permissionRequest は独立した `SessionAttention` に切り出したため含まない。
nonisolated enum SessionActivity: Sendable, Equatable {
    case idle
    case thinking
    case runningTool(String)
    /// 直近イベントが notification / permissionRequest で、エージェントが一時停止してユーザーの応答を待っている
    case waitingForUser
    case finished
    /// 活動中だったはずが `activeTimeout` を超えてイベントが届かない（応答停止/クラッシュ等のゾンビ）
    case unresponsive

    var displayLabel: String {
        switch self {
        case .idle: "Idle"
        case .thinking: "Thinking"
        case .runningTool(let name): name
        case .waitingForUser: "Waiting"
        case .finished: "Done"
        case .unresponsive: "Unresponsive"
        }
    }

    var systemImageName: String {
        switch self {
        case .idle: "circle"
        case .thinking: "brain"
        case .runningTool: "hammer"
        case .waitingForUser: "clock"
        case .finished: "checkmark.circle.fill"
        case .unresponsive: "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .idle: .textTertiary
        case .thinking: .accent
        case .runningTool: .statusRenamed
        case .waitingForUser: .accent
        case .finished: .statusClean
        case .unresponsive: .textTertiary
        }
    }

    /// エージェントが今まさに進行中（ユーザー応答待ちで一時停止している状態も含む）かどうか
    var isActive: Bool {
        switch self {
        case .idle, .finished, .unresponsive: false
        case .thinking, .runningTool, .waitingForUser: true
        }
    }

    /// これ以上状態が進展しない（メモリからの退避対象になりうる）かどうか
    var isTerminal: Bool {
        switch self {
        case .idle, .finished, .unresponsive: true
        case .thinking, .runningTool, .waitingForUser: false
        }
    }
}

/// セッションに「ユーザーが見るべき未読の出来事」があるかどうか。
/// `SessionActivity` とは独立した軸として持つ — エージェントが活動を再開しても、
/// ユーザーが acknowledge するまで消えない。
nonisolated struct SessionAttention: Sendable, Equatable {
    nonisolated enum Reason: Sendable, Equatable {
        case permissionRequest(tool: String?)
        case notification(message: String?)
    }

    let reason: Reason
    /// 通知/許可要求イベント自体の受信時刻（`events.last` ではなく、その出来事が起きた時刻）
    let occurredAt: Date
    let isAcknowledged: Bool
}

/// `AgentSession.snapshot(now:...)` が返す、ある時点でのセッション状態のスナップショット。
/// activity と attention を1回の走査でまとめて確定させる唯一の入口。
nonisolated struct SessionStateSnapshot: Sendable, Equatable {
    let activity: SessionActivity
    let attention: SessionAttention?
}
