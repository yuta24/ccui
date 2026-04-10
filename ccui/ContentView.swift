import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @State private var selectedWorktree: Worktree?
    @State private var worktreeStores: [Repository.ID: WorktreeStore] = [:]
    @State private var fileTreeStore: FileTreeStore?
    @State private var showingAddWorktree: WorktreeStore?
    @State private var initialBaseBranch: String?
    @State private var forceDeleteTarget: (Worktree, WorktreeStore)?
    @State private var showForceDeleteAlert = false
    @State private var sidebarWidth: CGFloat = 240
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            SidebarView(
                selectedWorktree: $selectedWorktree,
                worktreeStores: worktreeStores,
                onAddRepository: addRepository,
                onShowAddWorktree: { wtStore, branch in
                    initialBaseBranch = branch
                    showingAddWorktree = wtStore
                },
                onRemoveWorktree: removeWorktree
            )
            .frame(width: max(180, min(400, sidebarWidth + dragOffset)))
            .background(Color.surfaceBase)

            // Resize handle
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(width: 1)
                .contentShape(Rectangle().inset(by: -3))
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            sidebarWidth = max(180, min(400, sidebarWidth + value.translation.width))
                        }
                )
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }

            // Detail
            if let worktree = selectedWorktree {
                DetailView(worktree: worktree, fileTreeStore: fileTreeStore)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.surfacePrimary)
            } else {
                emptyState
            }
        }
        .background(Color.surfaceBase)
        .onChange(of: selectedWorktree) { _, newValue in
            if let wt = newValue {
                fileTreeStore = FileTreeStore(rootPath: wt.path)
                claudeEventStore.clearPending(for: wt.path)
            } else {
                fileTreeStore = nil
            }
        }
        .onChange(of: store.repositories) { _, newValue in
            syncWorktreeStores(with: newValue)
        }
        .sheet(item: $showingAddWorktree) { wtStore in
            AddWorktreeView(
                worktreeStore: wtStore,
                repositoryPath: wtStore.repositoryPath,
                initialBaseBranch: initialBaseBranch
            )
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
                worktreeStores[repo.id] = makeWorktreeStore(for: repo)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)

            Text("Select a worktree")
                .font(.uiLabel)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }

    // MARK: - State Sync

    private func makeWorktreeStore(for repo: Repository) -> WorktreeStore {
        let wtStore = WorktreeStore(repository: repo)
        wtStore.onWorktreesLoaded = { [weak claudeEventStore] worktrees in
            let paths = Set(worktrees.map(\.path))
            claudeEventStore?.addKnownPaths(paths)
        }
        return wtStore
    }

    private func syncWorktreeStores(with repositories: [Repository]) {
        let validIDs = Set(repositories.map(\.id))

        for repo in repositories where worktreeStores[repo.id] == nil {
            worktreeStores[repo.id] = makeWorktreeStore(for: repo)
        }

        for key in worktreeStores.keys where !validIDs.contains(key) {
            worktreeStores.removeValue(forKey: key)
        }

        let allWorktreePaths = Set(worktreeStores.values.flatMap(\.worktrees).map(\.path))
        terminalSessionStore.removeExcept(paths: allWorktreePaths)
        claudeEventStore.removeKnownPathsExcept(allWorktreePaths)

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
