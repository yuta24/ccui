import Foundation
import OSLog

@Observable
@MainActor
final class ClaudeEventStore {
    /// worktree パス → (セッション ID → AgentSession)
    private(set) var sessions: [String: [String: AgentSession]] = [:]

    /// worktree パスごとの既読タイムスタンプ（この時刻以前のイベントは確認済み）
    private(set) var acknowledgedUpTo: [String: Date] = [:]

    /// hook イベント受信ごとにインクリメントされる軽量カウンタ。
    /// onChange(of:) の等値比較コストを O(全イベント数) → O(1) に削減するために使う。
    private(set) var eventCounter: Int = 0

    /// ディスクからの読み込みに失敗した場合のエラーメッセージ
    private(set) var loadError: String?

    private let listenerService = UDSListenerService()
    private let persistenceCoordinator: ClaudeEventPersistenceCoordinator
    private let notificationService: NotificationService?
    private var knownWorktreePaths: Set<String> = []
    /// worktree パス → リポジトリパスのマッピング
    private var worktreeToRepository: [String: String] = [:]

    let maxEventsPerSessionLimit = 50
    private let maxSessionsPerWorktree = 20
    /// ディスク上に保持するワークツリーごとのセッション数上限
    private let maxDiskSessionsPerWorktree = 100
    /// この期間以上イベント更新がない進行中セッションは応答停止（unresponsive）とみなす
    private let activeStaleness: TimeInterval = 5 * 60
    /// この期間以上経過した attention は zombie とみなし、表示・カウントから除外する
    private let attentionStaleness: TimeInterval = 60 * 60

    init(
        persistence: any ClaudeEventPersistence = JSONFileClaudeEventPersistence(),
        notificationService: NotificationService? = nil
    ) {
        self.persistenceCoordinator = ClaudeEventPersistenceCoordinator(persistence: persistence)
        self.notificationService = notificationService
    }

    /// 共有 `ClaudeEventPersistenceCoordinator` を受け取るイニシャライザ。
    /// `SessionAnalyticsStore` 等の他ストアと同じディスク領域を読み書きする場合に
    /// このイニシャライザを使い、index.json の更新を直列化する。
    init(
        coordinator: ClaudeEventPersistenceCoordinator,
        notificationService: NotificationService? = nil
    ) {
        self.persistenceCoordinator = coordinator
        self.notificationService = notificationService
    }

    // MARK: - Lifecycle

    func start() {
        // ディスク読み込み中に届いたフックイベントを取りこぼさないため、UDS は先に listen を開始する。
        // handle(_:) は @MainActor なので、loadFromDisk の sessions 上書きと到着イベントの追記は直列化される。
        listenerService.start { [weak self] payload in
            self?.handle(payload)
        }
        Task {
            await loadFromDisk()
            await persistenceCoordinator.pruneOldSessions(maxPerWorktree: maxDiskSessionsPerWorktree)
        }
    }

    func stop() {
        listenerService.stop()
    }

    // MARK: - Query

    /// worktree 全体としての activity と attention の集約結果
    nonisolated struct WorktreeAgentSummary: Sendable, Equatable {
        let activity: SessionActivity
        /// 未読の attention を持つセッション数
        let pendingAttentionCount: Int
        /// 未読のまま完了したセッションがあるかどうか
        let hasUnacknowledgedFinished: Bool
    }

    func agentSummary(for worktreePath: String) -> WorktreeAgentSummary {
        guard let worktreeSessions = sessions[worktreePath] else {
            return WorktreeAgentSummary(activity: .idle, pendingAttentionCount: 0, hasUnacknowledgedFinished: false)
        }
        return Self.aggregateSummary(
            from: worktreeSessions.values,
            now: Date(),
            acknowledgedUpTo: acknowledgedUpTo[worktreePath],
            activeTimeout: activeStaleness,
            attentionTimeout: attentionStaleness
        )
    }

    /// 複数セッションの `snapshot` から worktree 全体としての状態を 1 パスで決定する。
    /// activity の優先度: runningTool > thinking > waitingForUser > unresponsive > finished > idle
    /// （同種が複数あれば lastEventAt が最も新しいものを採用）。
    /// attention は activity の優先順位とは独立に、未読件数と直近のものを集計する
    /// （「activity が変わっても attention は残り続ける」という設計のため、片方の優先順位がもう片方を隠さない）。
    nonisolated static func aggregateSummary(
        from sessions: some Collection<AgentSession>,
        now: Date,
        acknowledgedUpTo: Date?,
        activeTimeout: TimeInterval,
        attentionTimeout: TimeInterval
    ) -> WorktreeAgentSummary {
        var latestRunningTool: SessionActivity?
        var latestRunningToolAt: Date = .distantPast
        var hasThinking = false
        var hasWaitingForUser = false
        var hasUnresponsive = false
        var hasFinished = false

        var pendingAttentionCount = 0
        var hasUnacknowledgedFinished = false

        for session in sessions {
            let snapshot = session.snapshot(now: now, acknowledgedUpTo: acknowledgedUpTo, activeTimeout: activeTimeout, attentionTimeout: attentionTimeout)
            let at = session.lastEventAt ?? .distantPast

            switch snapshot.activity {
            case .runningTool:
                if at > latestRunningToolAt {
                    latestRunningToolAt = at
                    latestRunningTool = snapshot.activity
                }
            case .thinking:
                hasThinking = true
            case .waitingForUser:
                hasWaitingForUser = true
            case .unresponsive:
                hasUnresponsive = true
            case .finished:
                hasFinished = true
                if let cutoff = acknowledgedUpTo {
                    if at > cutoff { hasUnacknowledgedFinished = true }
                } else {
                    hasUnacknowledgedFinished = true
                }
            case .idle:
                break
            }

            if let attention = snapshot.attention, !attention.isAcknowledged {
                pendingAttentionCount += 1
            }
        }

        let activity: SessionActivity = if let latestRunningTool {
            latestRunningTool
        } else if hasThinking {
            .thinking
        } else if hasWaitingForUser {
            .waitingForUser
        } else if hasUnresponsive {
            .unresponsive
        } else if hasFinished {
            .finished
        } else {
            .idle
        }

        return WorktreeAgentSummary(activity: activity, pendingAttentionCount: pendingAttentionCount, hasUnacknowledgedFinished: hasUnacknowledgedFinished)
    }

    var activeAgentCount: Int {
        let now = Date()
        return sessions.values.flatMap(\.values).filter { session in
            switch session.snapshot(now: now, acknowledgedUpTo: nil, activeTimeout: activeStaleness, attentionTimeout: attentionStaleness).activity {
            case .thinking, .runningTool: true
            case .idle, .waitingForUser, .finished, .unresponsive: false
            }
        }.count
    }

    var doneAgentCount: Int {
        let now = Date()
        return sessions.values.flatMap { worktreeSessions in
            worktreeSessions.values.filter { session in
                let activity = session.snapshot(now: now, acknowledgedUpTo: nil, activeTimeout: activeStaleness, attentionTimeout: attentionStaleness).activity
                return activity == .finished && isSessionUnacknowledged(session)
            }
        }.count
    }

    var attentionAgentCount: Int {
        let now = Date()
        return sessions.reduce(into: 0) { count, entry in
            let (worktreePath, worktreeSessions) = entry
            let cutoff = acknowledgedUpTo[worktreePath]
            count += worktreeSessions.values.filter { session in
                guard let attention = session.snapshot(now: now, acknowledgedUpTo: cutoff, activeTimeout: activeStaleness, attentionTimeout: attentionStaleness).attention else { return false }
                return !attention.isAcknowledged
            }.count
        }
    }

    // MARK: - Mutations

    /// worktree を既読にする（履歴は保持したまま、最新イベントまでを確認済みにする）
    func acknowledge(for worktreePath: String) {
        let latest = sessions[worktreePath]?.values
            .compactMap(\.lastEventAt)
            .max() ?? Date()
        acknowledgedUpTo[worktreePath] = latest
    }

    /// 既知の全 worktree を現時点で既読にする（ステータスバークリック等で呼び出す）
    func acknowledgeAll() {
        let now = Date()
        for path in sessions.keys {
            acknowledgedUpTo[path] = now
        }
    }

    func annotateSession(
        worktreePath: String,
        sessionId: String,
        outcome: SessionOutcome?,
        failureReasons: Set<FailureReason>
    ) {
        guard var worktreeSessions = sessions[worktreePath],
              var session = worktreeSessions[sessionId] else { return }
        session.setAnnotation(outcome: outcome, failureReasons: failureReasons)
        worktreeSessions[sessionId] = session
        sessions[worktreePath] = worktreeSessions

        let coordinator = persistenceCoordinator
        let repoPath = worktreeToRepository[worktreePath]
        Task { await coordinator.saveSession(session, worktreePath: worktreePath, repositoryPath: repoPath) }
    }

    func addKnownPaths(_ paths: Set<String>, repositoryPath: String) {
        knownWorktreePaths.formUnion(paths)
        for path in paths {
            worktreeToRepository[path] = repositoryPath
        }
    }

    /// 指定パス以外をメモリから除去（ディスク上のセッションデータは保持し、統計・分析に活用する）
    func removeKnownPathsExcept(_ paths: Set<String>) {
        knownWorktreePaths.formIntersection(paths)
        sessions = sessions.filter { paths.contains($0.key) }
        acknowledgedUpTo = acknowledgedUpTo.filter { paths.contains($0.key) }
        worktreeToRepository = worktreeToRepository.filter { paths.contains($0.key) }
    }

    /// リポジトリ削除時にディスクからもセッションデータを削除する
    func removeRepositorySessions(worktreePaths: Set<String>) {
        let coordinator = persistenceCoordinator
        for path in worktreePaths {
            Task { await coordinator.removeWorktree(path) }
        }
    }

    // MARK: - Internal

    private func handle(_ payload: ClaudeHookPayload) {
        let resolvedPath = resolveWorktreePath(for: payload.cwd)
        let event = ClaudeEvent(worktreePath: resolvedPath, payload: payload)
        let sid = event.sessionId

        var worktreeSessions = sessions[resolvedPath] ?? [:]
        var session = worktreeSessions[sid] ?? AgentSession(id: sid, worktreePath: resolvedPath)
        session.append(event, maxEvents: maxEventsPerSessionLimit)
        worktreeSessions[sid] = session

        if worktreeSessions.count > maxSessionsPerWorktree {
            evictTerminalSessions(&worktreeSessions, excluding: sid)
        }

        sessions[resolvedPath] = worktreeSessions
        eventCounter += 1

        notificationService?.dispatch(event: event)

        // addKnownPaths 前にイベントが到着した場合は保存を遅延させない（セッションデータは保存する）が、
        // repositoryPath は判明次第 updateIndex で補完される
        let coordinator = persistenceCoordinator
        let repoPath = worktreeToRepository[resolvedPath]
        Task { await coordinator.saveSession(session, worktreePath: resolvedPath, repositoryPath: repoPath) }
    }

    /// 終了済みセッションを古い順にメモリから退避（ディスク上のファイルは保持）
    private func evictTerminalSessions(_ map: inout [String: AgentSession], excluding currentSessionId: String) {
        let now = Date()
        let terminalSessions = map.values
            .filter { $0.id != currentSessionId && $0.isTerminal(now: now, activeTimeout: activeStaleness) }
            .sorted(by: { ($0.lastEventAt ?? .distantPast) < ($1.lastEventAt ?? .distantPast) })

        var toEvict = map.count - maxSessionsPerWorktree
        for session in terminalSessions where toEvict > 0 {
            map.removeValue(forKey: session.id)
            toEvict -= 1
        }
    }

    private func isSessionUnacknowledged(_ session: AgentSession) -> Bool {
        guard let lastEvent = session.lastEventAt else { return false }
        if let cutoff = acknowledgedUpTo[session.worktreePath] {
            return lastEvent > cutoff
        }
        return true
    }

    /// cwd がサブディレクトリの場合、既知のワークツリーパスと prefix マッチする（最長マッチ優先）
    private func resolveWorktreePath(for cwd: String) -> String {
        knownWorktreePaths
            .filter { cwd == $0 || cwd.hasPrefix($0 + "/") }
            .max(by: { $0.count < $1.count })
            ?? cwd
    }

    // MARK: - Persistence

    private func loadFromDisk() async {
        do {
            var loaded = try await persistenceCoordinator.loadAll()
            // メモリ上限を適用（ディスク上は maxDiskSessionsPerWorktree 件まで保持）
            let now = Date()
            for (path, worktreeSessions) in loaded where worktreeSessions.count > maxSessionsPerWorktree {
                var mutable = worktreeSessions
                let terminalSessions = mutable.values
                    .filter { $0.isTerminal(now: now, activeTimeout: activeStaleness) }
                    .sorted(by: { ($0.lastEventAt ?? .distantPast) < ($1.lastEventAt ?? .distantPast) })
                var toEvict = mutable.count - maxSessionsPerWorktree
                for session in terminalSessions where toEvict > 0 {
                    mutable.removeValue(forKey: session.id)
                    toEvict -= 1
                }
                loaded[path] = mutable
            }
            // start() でリスナーを先に開始しているため、loadFromDisk の完了前に
            // フックイベントが届いて sessions に書き込まれている可能性がある。
            // 単純な代入で上書きするとそれらが消えるので、in-memory 側を優先してマージする。
            for (path, inMemorySessions) in sessions {
                var target = loaded[path] ?? [:]
                for (sid, memSession) in inMemorySessions {
                    if let diskSession = target[sid],
                       (diskSession.lastEventAt ?? .distantPast) > (memSession.lastEventAt ?? .distantPast) {
                        // ディスク側の方が新しい（saveSession が先行した）場合のみディスクを優先
                        target[sid] = diskSession
                    } else {
                        target[sid] = memSession
                    }
                }
                loaded[path] = target
            }
            sessions = loaded
            // 起動時点で既存セッションは全て既読扱い。ステータスバーは「このアプリ
            // セッション中に新規発生したもの」だけを積み上げる。
            for path in sessions.keys {
                acknowledgedUpTo[path] = now
            }
        } catch {
            Logger.store.error("Failed to load claude events from disk: \(error)")
            // sessions は in-memory に届いたイベントを保持するため空代入しない
            loadError = "Failed to load session history: \(error.localizedDescription)"
        }
    }
}

