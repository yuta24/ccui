import OSLog
import SwiftUI

/// repository / worktree の CRUD とそのカスケード処理を担う。
/// カスケード（他 Store のクリーンアップ）は `AppEventBus` 経由で通知し、
/// 各 Store が自身で subscribe して反映する。
@Observable
@MainActor
final class WorktreeLifecycleCoordinator {
    private(set) var worktreeStores: [Repository.ID: WorktreeStore] = [:]

    var showingAddWorktree: WorktreeStore?
    var initialBaseBranch: String?
    var forceDeleteTarget: (Worktree, WorktreeStore)?
    var isForceDeleteAlertPresented = false
    var removeRepositoryTarget: (Repository, RepositoryStore)?
    var isRemoveRepositoryAlertPresented = false

    var errorMessage: String?
    var isErrorAlertPresented = false

    private let eventBus: AppEventBus

    init(eventBus: AppEventBus) {
        self.eventBus = eventBus
    }

    private func makeWorktreeStore(for repo: Repository) -> WorktreeStore {
        WorktreeStore(repository: repo, eventBus: eventBus)
    }

    func syncWorktreeStores(with repositories: [Repository]) {
        let validIDs = Set(repositories.map(\.id))
        for repo in repositories where worktreeStores[repo.id] == nil {
            worktreeStores[repo.id] = makeWorktreeStore(for: repo)
        }
        var removedRepoPaths: Set<String> = []
        for key in worktreeStores.keys where !validIDs.contains(key) {
            if let store = worktreeStores[key] {
                removedRepoPaths.formUnion(store.worktrees.map(\.path))
                store.tearDown()
            }
            worktreeStores.removeValue(forKey: key)
        }
        let allWorktreePaths = Set(worktreeStores.values.flatMap(\.worktrees).map(\.path))
        if !removedRepoPaths.isEmpty {
            eventBus.publish(.repositoriesRemoved(worktreePaths: removedRepoPaths))
        }
        eventBus.publish(.worktreesSynced(allWorktreePaths: allWorktreePaths))
    }

    func ensureWorktreeStores(for repositories: [Repository]) {
        for repo in repositories where worktreeStores[repo.id] == nil {
            worktreeStores[repo.id] = makeWorktreeStore(for: repo)
        }
    }

    func addRepository(store: RepositoryStore) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Repository"
        panel.message = "Select a folder to add as a repository"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.addRepository(at: url)
    }

    func showAddWorktreeSheet(store: WorktreeStore, branch: String?) {
        initialBaseBranch = branch
        showingAddWorktree = store
    }

    func removeWorktree(_ wt: Worktree, from wtStore: WorktreeStore) {
        Task {
            do {
                try await wtStore.remove(wt)
                eventBus.publish(.worktreeRemoved(path: wt.path))
                forceDeleteTarget = nil
            } catch let error as GitError {
                if case .worktreeDirty = error {
                    forceDeleteTarget = (wt, wtStore)
                    isForceDeleteAlertPresented = true
                } else {
                    forceDeleteTarget = nil
                    Logger.store.error("Failed to remove worktree: \(error)")
                    errorMessage = error.localizedDescription
                    isErrorAlertPresented = true
                }
            } catch {
                forceDeleteTarget = nil
                Logger.store.error("Failed to remove worktree: \(error)")
                errorMessage = error.localizedDescription
                isErrorAlertPresented = true
            }
        }
    }

    func confirmRemoveRepository(_ repository: Repository, from store: RepositoryStore) {
        removeRepositoryTarget = (repository, store)
        isRemoveRepositoryAlertPresented = true
    }

    func executeRemoveRepository() {
        guard let (repository, store) = removeRepositoryTarget else { return }
        store.remove(repository)
        removeRepositoryTarget = nil
    }

    func forceDeleteWorktree() {
        guard let (wt, wtStore) = forceDeleteTarget else { return }
        Task {
            do {
                try await wtStore.remove(wt, force: true)
                eventBus.publish(.worktreeRemoved(path: wt.path))
                forceDeleteTarget = nil
            } catch {
                forceDeleteTarget = nil
                Logger.store.error("Failed to force remove worktree: \(error)")
                errorMessage = error.localizedDescription
                isErrorAlertPresented = true
            }
        }
    }
}
