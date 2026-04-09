import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @State private var selectedWorktree: Worktree?
    @State private var worktreeStores: [Repository.ID: WorktreeStore] = [:]
    @State private var fileTreeStore: FileTreeStore?
    @State private var showingAddWorktree: WorktreeStore?

    var body: some View {
        NavigationSplitView {
            sidebar
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
            let validIDs = Set(newValue.map(\.id))
            // Create worktree stores for new repos
            for repo in newValue where worktreeStores[repo.id] == nil {
                worktreeStores[repo.id] = WorktreeStore(repository: repo)
            }
            // Clean up worktree stores for removed repos
            for key in worktreeStores.keys where !validIDs.contains(key) {
                worktreeStores.removeValue(forKey: key)
            }
            // Clean up terminal sessions
            let allWorktreePaths = Set(worktreeStores.values.flatMap(\.worktrees).map(\.path))
            terminalSessionStore.removeExcept(paths: allWorktreePaths)
            // Clear selection if its repo was removed
            if let selected = selectedWorktree, !validIDs.contains(selected.repositoryID) {
                selectedWorktree = nil
            }
        }
        .sheet(item: $showingAddWorktree) { wtStore in
            AddWorktreeView(worktreeStore: wtStore)
        }
        .onAppear {
            for repo in store.repositories where worktreeStores[repo.id] == nil {
                worktreeStores[repo.id] = WorktreeStore(repository: repo)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header with add repository button
            HStack {
                Text("Repositories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    addRepository()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add Repository")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if store.repositories.isEmpty {
                Spacer()
                Text("Add a repository to get started")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List(selection: $selectedWorktree) {
                    ForEach(store.repositories) { repo in
                        repositorySection(repo)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    @ViewBuilder
    private func repositorySection(_ repo: Repository) -> some View {
        if let wtStore = worktreeStore(for: repo) {
            repositorySectionContent(repo: repo, wtStore: wtStore)
        } else {
            Section(repo.name) {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func repositorySectionContent(repo: Repository, wtStore: WorktreeStore) -> some View {
        Section {
            if wtStore.isLoading && wtStore.worktrees.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let error = wtStore.errorMessage, wtStore.worktrees.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(wtStore.worktrees) { wt in
                    worktreeRow(wt, in: wtStore)
                        .tag(wt)
                        .contextMenu {
                            if !wt.isMain {
                                Button("Remove Worktree", role: .destructive) {
                                    removeWorktree(wt, from: wtStore)
                                }
                            }
                        }
                }

                Button {
                    showingAddWorktree = wtStore
                } label: {
                    Label("Add Worktree", systemImage: "plus.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } header: {
            HStack {
                Text(repo.name)
                Spacer()
                Button {
                    Task { await wtStore.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                .help("Reload worktrees")
            }
            .contextMenu {
                Button("Remove Repository", role: .destructive) {
                    store.remove(repo)
                }
            }
        }
        .task(id: repo.id) {
            if wtStore.worktrees.isEmpty && !wtStore.isLoading {
                await wtStore.load()
            }
        }
    }

    private func worktreeRow(_ wt: Worktree, in store: WorktreeStore) -> some View {
        HStack {
            Label {
                Text(wt.displayName)
                    .lineLimit(1)
            } icon: {
                Image(systemName: wt.isMain ? "house" : "arrow.triangle.branch")
                    .foregroundStyle(wt.isMain ? .blue : .secondary)
            }
            Spacer()
            if let count = store.statusCounts[wt.path] {
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.2))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
    }

    // MARK: - WorktreeStore management

    private func worktreeStore(for repo: Repository) -> WorktreeStore? {
        worktreeStores[repo.id]
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
                if selectedWorktree == wt {
                    selectedWorktree = nil
                }
                try await wtStore.remove(wt)
                terminalSessionStore.remove(for: wt.path)
            } catch {
                print("[ContentView] Failed to remove worktree: \(error)")
            }
        }
    }
}
