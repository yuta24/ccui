import SwiftUI

struct RepositorySectionView: View {
    let repository: Repository
    let worktreeStore: WorktreeStore
    var searchQuery: String = ""
    @Environment(RepositoryStore.self) private var store
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(WorktreeLifecycleCoordinator.self) private var worktreeLifecycleCoordinator

    private var isMissing: Bool {
        !store.exists(repository)
    }

    private var filteredWorktrees: [Worktree] {
        guard !searchQuery.isEmpty else { return worktreeStore.worktrees }
        if QuickOpenStore.fuzzyScore(query: searchQuery, candidate: repository.name) != nil {
            return worktreeStore.worktrees
        }
        return worktreeStore.worktrees.filter { wt in
            QuickOpenStore.fuzzyScore(query: searchQuery, candidate: wt.displayName) != nil
        }
    }

    private var matchesSearch: Bool {
        Self.matches(repository: repository, worktrees: worktreeStore.worktrees, query: searchQuery)
    }

    static func matches(repository: Repository, worktrees: [Worktree], query: String) -> Bool {
        guard !query.isEmpty else { return true }
        if QuickOpenStore.fuzzyScore(query: query, candidate: repository.name) != nil {
            return true
        }
        return worktrees.contains { wt in
            QuickOpenStore.fuzzyScore(query: query, candidate: wt.displayName) != nil
        }
    }

    var body: some View {
        Group {
            if matchesSearch {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader

                    if isMissing {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.statusWarning)
                            Text("Repository not found on disk")
                                .font(.uiCaption)
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    } else {
                        worktreeList
                    }
                }

                sectionDivider
            }
        }
        .task(id: repository.id) {
            guard !isMissing else { return }
            if worktreeStore.worktrees.isEmpty && !worktreeStore.isLoading {
                await worktreeStore.load()
            }
            // LazyVStack のスクロールアウトで view が再生成されると worktrees は既にロード済みで
            // load() が走らない。startWatching を if 内に置くと watcher が起動されず、
            // 末尾の stopWatching だけ走って前回の watcher を止めてしまうので、必ず起動する。
            // FileSystemWatcher.start は内部で stop してから start するため再呼び出しも安全。
            worktreeStore.startWatching()
            // task がキャンセルされる（view 消失 / id 変化）まで待機し、
            // キャンセル時に watcher を停止して FileSystemWatcher のリソースリークを防ぐ。
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
            }
            worktreeStore.stopWatching()
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(spacing: 6) {
            Text(repository.name)
                .font(.uiCaption)
                .foregroundStyle(Color.textPrimary)
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(1)

            Spacer()

            Button {
                Task { await worktreeStore.load() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .medium))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .help("Reload worktrees")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contextMenu {
            Button("Remove Repository", role: .destructive) {
                store.remove(repository)
            }
        }
    }

    // MARK: - Worktree List

    @ViewBuilder
    private var worktreeList: some View {
        if worktreeStore.isLoading && worktreeStore.worktrees.isEmpty {
            PulsingDotsView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        } else if let error = worktreeStore.errorMessage, worktreeStore.worktrees.isEmpty {
            Text(error)
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        } else {
            ForEach(filteredWorktrees) { wt in
                let summary = claudeEventStore.agentSummary(for: wt.path)

                WorktreeRowView(
                    worktree: wt,
                    isSelected: navigationStore.selectedWorktree == wt,
                    summary: summary,
                    statusCount: worktreeStore.statusCounts[wt.path],
                    onSelect: {
                        navigationStore.selectWorktree(wt, claudeEventStore: claudeEventStore, lifecycle: worktreeLifecycleCoordinator)
                    }
                )
                .id(wt.id)
                .contextMenu {
                    worktreeContextMenu(wt)
                }
            }

            if searchQuery.isEmpty {
                addWorktreeButton
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func worktreeContextMenu(_ wt: Worktree) -> some View {
        if let branch = wt.branch {
            Button("Add Worktree from \"\(branch)\"...") {
                worktreeLifecycleCoordinator.showAddWorktreeSheet(store: worktreeStore, branch: branch)
            }
            Divider()
        }
        Button("Reveal in Finder") {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: wt.path)
        }
        let editors = ExternalEditor.installed
        if !editors.isEmpty {
            Menu("Open with") {
                ForEach(editors) { editor in
                    Button(editor.name) {
                        editor.open(path: wt.path)
                    }
                }
            }
        }
        if !wt.isMain {
            Divider()
            Button("Remove Worktree", role: .destructive) {
                worktreeLifecycleCoordinator.removeWorktree(wt, from: worktreeStore)
            }
        }
    }

    // MARK: - Add Worktree Button

    private var addWorktreeButton: some View {
        Button {
            worktreeLifecycleCoordinator.showAddWorktreeSheet(store: worktreeStore, branch: nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .medium))
                Text("Add Worktree")
                    .font(.uiCaption)
            }
            .foregroundStyle(Color.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Divider

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(height: 1)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
    }
}
