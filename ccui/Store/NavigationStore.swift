import Foundation

/// 選択中の worktree とそれに紐づく FileTreeStore を保持する。
@Observable
@MainActor
final class NavigationStore {
    var selectedWorktree: Worktree?
    private(set) var fileTreeStore: FileTreeStore?

    init(eventBus: AppEventBus) {
        eventBus.subscribe { [weak self] event in
            self?.handle(event)
        }
    }

    func selectWorktree(_ wt: Worktree?, claudeEventStore: ClaudeEventStore, lifecycle: WorktreeLifecycleCoordinator) {
        guard let wt else {
            selectedWorktree = nil
            fileTreeStore = nil
            return
        }

        guard FileManager.default.fileExists(atPath: wt.path) else {
            selectedWorktree = nil
            fileTreeStore = nil
            lifecycle.errorMessage = "Worktree path no longer exists: \(wt.path)"
            lifecycle.isErrorAlertPresented = true
            return
        }

        selectedWorktree = wt
        let store = FileTreeStore(rootPath: wt.path)
        fileTreeStore = store
        claudeEventStore.acknowledge(for: wt.path)
        Task { await store.load() }
    }

    private func handle(_ event: AppEvent) {
        switch event {
        case .worktreesSynced(let allWorktreePaths):
            if let selected = selectedWorktree, !allWorktreePaths.contains(selected.path) {
                selectedWorktree = nil
                fileTreeStore = nil
            }
        case .worktreeRemoved(let path):
            if selectedWorktree?.path == path {
                selectedWorktree = nil
                fileTreeStore = nil
            }
        case .worktreesLoaded, .repositoriesRemoved:
            break
        }
    }
}
