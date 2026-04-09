import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @State private var selectedWorktree: Worktree?
    @State private var worktreeStores: [Repository.ID: WorktreeStore] = [:]
    @State private var fileTreeStore: FileTreeStore?
    @State private var showingAddWorktree: WorktreeStore?
    @State private var forceDeleteTarget: (Worktree, WorktreeStore)?
    @State private var showForceDeleteAlert = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedWorktree: $selectedWorktree,
                worktreeStores: worktreeStores,
                onAddRepository: addRepository,
                onShowAddWorktree: { showingAddWorktree = $0 },
                onRemoveWorktree: removeWorktree
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
        } detail: {
            if let worktree = selectedWorktree {
                DetailView(worktree: worktree, fileTreeStore: fileTreeStore)
            } else {
                Text("Select a worktree")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
        .onChange(of: selectedWorktree) { _, newValue in
            if let wt = newValue {
                fileTreeStore = FileTreeStore(rootPath: wt.path)
            } else {
                fileTreeStore = nil
            }
        }
        .onChange(of: store.repositories) { _, newValue in
            syncWorktreeStores(with: newValue)
        }
        .sheet(item: $showingAddWorktree) { wtStore in
            AddWorktreeView(worktreeStore: wtStore, repositoryPath: wtStore.repositoryPath)
        }
        .alert("Uncommitted Changes", isPresented: $showForceDeleteAlert) {
            Button("Force Delete", role: .destructive) {
                if let (wt, wtStore) = forceDeleteTarget {
                    forceDeleteWorktree(wt, from: wtStore)
                }
            }
            Button("Cancel", role: .cancel) {
                forceDeleteTarget = nil
            }
        } message: {
            Text("This worktree has uncommitted changes. Force delete will discard them.")
        }
        .onAppear {
            for repo in store.repositories where worktreeStores[repo.id] == nil {
                worktreeStores[repo.id] = WorktreeStore(repository: repo)
            }
        }
    }

    // MARK: - State Sync

    private func syncWorktreeStores(with repositories: [Repository]) {
        let validIDs = Set(repositories.map(\.id))

        for repo in repositories where worktreeStores[repo.id] == nil {
            worktreeStores[repo.id] = WorktreeStore(repository: repo)
        }

        for key in worktreeStores.keys where !validIDs.contains(key) {
            worktreeStores.removeValue(forKey: key)
        }

        let allWorktreePaths = Set(worktreeStores.values.flatMap(\.worktrees).map(\.path))
        terminalSessionStore.removeExcept(paths: allWorktreePaths)

        if let selected = selectedWorktree, !validIDs.contains(selected.repositoryID) {
            selectedWorktree = nil
        }
    }

    // MARK: - Actions

    private func addRepository() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Repository"
        panel.message = "Select a folder to add as a repository"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.addRepository(at: url)
    }

    private func removeWorktree(_ wt: Worktree, from wtStore: WorktreeStore) {
        Task {
            do {
                try await wtStore.remove(wt)
                terminalSessionStore.remove(for: wt.path)
                if selectedWorktree == wt {
                    selectedWorktree = nil
                }
            } catch let error as GitError {
                if case .worktreeDirty = error {
                    forceDeleteTarget = (wt, wtStore)
                    showForceDeleteAlert = true
                } else {
                    print("[ContentView] Failed to remove worktree: \(error)")
                }
            } catch {
                print("[ContentView] Failed to remove worktree: \(error)")
            }
        }
    }

    private func forceDeleteWorktree(_ wt: Worktree, from wtStore: WorktreeStore) {
        Task {
            do {
                try await wtStore.remove(wt, force: true)
                terminalSessionStore.remove(for: wt.path)
                if selectedWorktree == wt {
                    selectedWorktree = nil
                }
                forceDeleteTarget = nil
            } catch {
                print("[ContentView] Failed to force remove worktree: \(error)")
            }
        }
    }
}
