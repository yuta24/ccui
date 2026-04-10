import Foundation

@Observable
@MainActor
final class ClaudeEventStore {
    private(set) var pendingEvents: [String: ClaudeEvent] = [:]

    private let listenerService = UDSListenerService()
    private var knownWorktreePaths: Set<String> = []

    func start() {
        listenerService.start { [weak self] payload in
            self?.handle(payload)
        }
    }

    func stop() {
        listenerService.stop()
    }

    func clearPending(for worktreePath: String) {
        pendingEvents.removeValue(forKey: worktreePath)
    }

    func addKnownPaths(_ paths: Set<String>) {
        knownWorktreePaths.formUnion(paths)
    }

    /// 指定パス以外を除去（リポジトリ削除時のクリーンアップ用）
    func removeKnownPathsExcept(_ paths: Set<String>) {
        knownWorktreePaths.formIntersection(paths)
    }

    private func handle(_ payload: ClaudeHookPayload) {
        let resolvedPath = resolveWorktreePath(for: payload.cwd)
        let event = ClaudeEvent(worktreePath: resolvedPath, payload: payload)
        pendingEvents[resolvedPath] = event
    }

    /// cwd がサブディレクトリの場合、既知のワークツリーパスと prefix マッチする
    private func resolveWorktreePath(for cwd: String) -> String {
        for path in knownWorktreePaths {
            if cwd == path || cwd.hasPrefix(path + "/") {
                return path
            }
        }
        return cwd
    }
}
