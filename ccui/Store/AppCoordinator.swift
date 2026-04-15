import OSLog
import SwiftUI

@Observable
@MainActor
final class AppCoordinator {
    var selectedWorktree: Worktree?
    private(set) var worktreeStores: [Repository.ID: WorktreeStore] = [:]
    private(set) var fileTreeStore: FileTreeStore?

    var showingAddWorktree: WorktreeStore?
    var initialBaseBranch: String?
    var forceDeleteTarget: (Worktree, WorktreeStore)?
    var showForceDeleteAlert = false

    // MARK: - Worktree Store Lifecycle

    func makeWorktreeStore(for repo: Repository, claudeEventStore: ClaudeEventStore) -> WorktreeStore {
        let wtStore = WorktreeStore(repository: repo)
        wtStore.onWorktreesLoaded = { [weak claudeEventStore] worktrees in
            let paths = Set(worktrees.map(\.path))
            claudeEventStore?.addKnownPaths(paths)
        }
        return wtStore
    }

    func syncWorktreeStores(
        with repositories: [Repository],
        terminalSessionStore: TerminalSessionStore,
        shellSessionStore: ShellSessionStore,
        claudeEventStore: ClaudeEventStore
    ) {
        let validIDs = Set(repositories.map(\.id))

        for repo in repositories where worktreeStores[repo.id] == nil {
            worktreeStores[repo.id] = makeWorktreeStore(for: repo, claudeEventStore: claudeEventStore)
        }

        for key in worktreeStores.keys where !validIDs.contains(key) {
            worktreeStores[key]?.tearDown()
            worktreeStores.removeValue(forKey: key)
        }

        let allWorktreePaths = Set(worktreeStores.values.flatMap(\.worktrees).map(\.path))
        terminalSessionStore.removeExcept(paths: allWorktreePaths)
        shellSessionStore.removeExcept(paths: allWorktreePaths)
        claudeEventStore.removeKnownPathsExcept(allWorktreePaths)

        if let selected = selectedWorktree, !validIDs.contains(selected.repositoryID) {
            selectedWorktree = nil
        }
    }

    func ensureWorktreeStores(
        for repositories: [Repository],
        claudeEventStore: ClaudeEventStore
    ) {
        for repo in repositories where worktreeStores[repo.id] == nil {
            worktreeStores[repo.id] = makeWorktreeStore(for: repo, claudeEventStore: claudeEventStore)
        }
    }

    // MARK: - Selection

    func selectWorktree(_ wt: Worktree?, claudeEventStore: ClaudeEventStore) {
        selectedWorktree = wt
        if let wt {
            let store = FileTreeStore(rootPath: wt.path)
            fileTreeStore = store
            claudeEventStore.acknowledge(for: wt.path)
            Task { await store.load() }
        } else {
            fileTreeStore = nil
        }
    }

    // MARK: - Repository Actions

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

    // MARK: - Worktree Actions

    func showAddWorktreeSheet(store: WorktreeStore, branch: String?) {
        initialBaseBranch = branch
        showingAddWorktree = store
    }

    func removeWorktree(
        _ wt: Worktree,
        from wtStore: WorktreeStore,
        terminalSessionStore: TerminalSessionStore,
        shellSessionStore: ShellSessionStore
    ) {
        Task {
            do {
                try await wtStore.remove(wt)
                terminalSessionStore.remove(for: wt.path)
                shellSessionStore.removeAll(for: wt.path)
                if selectedWorktree == wt {
                    selectedWorktree = nil
                    fileTreeStore = nil
                }
            } catch let error as GitError {
                if case .worktreeDirty = error {
                    forceDeleteTarget = (wt, wtStore)
                    showForceDeleteAlert = true
                } else {
                    Logger.store.error("Failed to remove worktree: \(error)")
                }
            } catch {
                Logger.store.error("Failed to remove worktree: \(error)")
            }
        }
    }

    func forceDeleteWorktree(terminalSessionStore: TerminalSessionStore, shellSessionStore: ShellSessionStore) {
        guard let (wt, wtStore) = forceDeleteTarget else { return }
        Task {
            do {
                try await wtStore.remove(wt, force: true)
                terminalSessionStore.remove(for: wt.path)
                shellSessionStore.removeAll(for: wt.path)
                if selectedWorktree == wt {
                    selectedWorktree = nil
                    fileTreeStore = nil
                }
                forceDeleteTarget = nil
            } catch {
                Logger.store.error("Failed to force remove worktree: \(error)")
            }
        }
    }
}
