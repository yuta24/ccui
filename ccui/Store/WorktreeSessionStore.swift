import Foundation
import OSLog

@Observable
@MainActor
final class WorktreeSessionStore {
    private(set) var entries: [String: [WorktreeSessionEntry]] = [:]
    private let persistence: any WorktreeSessionPersistence
    private var debouncedSaveTask: Task<Void, Never>?

    init(eventBus: AppEventBus, persistence: any WorktreeSessionPersistence = JSONFileWorktreeSessionPersistence()) {
        self.persistence = persistence
        do {
            entries = try persistence.load()
        } catch {
            Logger.store.error("Failed to load worktree sessions: \(error)")
        }
        eventBus.subscribe { [weak self] event in
            self?.handle(event)
        }
    }

    private func handle(_ event: AppEvent) {
        switch event {
        case .worktreesSynced(let allWorktreePaths):
            removeExcept(allWorktreePaths)
        case .worktreeRemoved, .worktreesLoaded, .repositoriesRemoved:
            break
        }
    }

    /// worktree の最新セッションの sessionId を返す。未登録なら新規 UUID を生成して追加する。
    func currentSessionId(for worktreePath: String) -> String {
        if let last = entries[worktreePath]?.last {
            return last.sessionId
        }
        return createSession(for: worktreePath)
    }

    /// 該当 worktree に既存セッションがあるか（再開対象があるか）を判定する
    func isResume(for worktreePath: String) -> Bool {
        entries[worktreePath]?.isEmpty == false
    }

    /// 新規セッションを作成して追加し、sessionId を返す
    @discardableResult
    func createSession(for worktreePath: String) -> String {
        let entry = WorktreeSessionEntry(sessionId: UUID().uuidString, createdAt: Date())
        entries[worktreePath, default: []].append(entry)
        save()
        return entry.sessionId
    }

    /// セッションのタイトルを更新する
    func updateTitle(for worktreePath: String, sessionId: String, title: String) {
        guard var list = entries[worktreePath],
              let index = list.firstIndex(where: { $0.sessionId == sessionId }) else { return }
        list[index].title = title
        entries[worktreePath] = list
        scheduleSave()
    }

    /// セッションを削除する
    func removeSession(for worktreePath: String, sessionId: String) {
        guard var list = entries[worktreePath] else { return }
        list.removeAll { $0.sessionId == sessionId }
        if list.isEmpty {
            entries.removeValue(forKey: worktreePath)
        } else {
            entries[worktreePath] = list
        }
        save()
    }

    func removeExcept(_ paths: Set<String>) {
        entries = entries.filter { paths.contains($0.key) }
        save()
    }

    /// デバウンス付き保存（高頻度な updateTitle 用）
    private func scheduleSave() {
        debouncedSaveTask?.cancel()
        debouncedSaveTask = Task {
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            save()
        }
    }

    func save() {
        do {
            try persistence.save(entries)
        } catch {
            Logger.store.error("Failed to save worktree sessions: \(error)")
        }
    }
}
