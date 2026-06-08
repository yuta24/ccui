import SwiftUI

struct RepositorySectionView: View {
    let repository: Repository
    let worktreeStore: WorktreeStore
    @Environment(RepositoryStore.self) private var store
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(ShellSessionStore.self) private var shellSessionStore
    @Environment(BottomPanelState.self) private var bottomPanelState

    private var isMissing: Bool {
        !store.exists(repository)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader

            if isMissing {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
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
        .task(id: repository.id) {
            guard !isMissing else { return }
            if worktreeStore.worktrees.isEmpty && !worktreeStore.isLoading {
                await worktreeStore.load()
            }
            // LazyVStack のスクロールアウトで view が再生成されると worktrees は既にロード済みで
            // load() が走らない。startWatching を if 内に置くと watcher が起動されず、
            // 末尾の stopWatching だけ走って前回の watcher を止めてしまうので、必ず起動する。
            // GitDirectoryWatcher.start は内部で stop してから start するため再呼び出しも安全。
            worktreeStore.startWatching()
            // task がキャンセルされる（view 消失 / id 変化）まで待機し、
            // キャンセル時に watcher を停止して GitDirectoryWatcher の fd リークを防ぐ。
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
            }
            worktreeStore.stopWatching()
        }

        sectionDivider
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(spacing: 6) {
            Text(repository.name)
                .font(.uiCaption)
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(1)

            Spacer()

            Button {
                Task { await worktreeStore.load() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
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
            ForEach(worktreeStore.worktrees) { wt in
                let summary = claudeEventStore.agentSummary(for: wt.path)
                let isHighlighted = summary.activity.isActive || claudeEventStore.hasUnacknowledged(for: wt.path)

                WorktreeRowView(
                    worktree: wt,
                    isSelected: coordinator.selectedWorktree == wt,
                    summary: summary,
                    isHighlighted: isHighlighted,
                    statusCount: worktreeStore.statusCounts[wt.path],
                    onSelect: {
                        coordinator.selectWorktree(wt, claudeEventStore: claudeEventStore)
                    }
                )
                .contextMenu {
                    worktreeContextMenu(wt)
                }
            }

            addWorktreeButton
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func worktreeContextMenu(_ wt: Worktree) -> some View {
        if let branch = wt.branch {
            Button("Add Worktree from \"\(branch)\"...") {
                coordinator.showAddWorktreeSheet(store: worktreeStore, branch: branch)
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
                coordinator.removeWorktree(wt, from: worktreeStore, terminalSessionStore: terminalSessionStore, shellSessionStore: shellSessionStore, bottomPanelState: bottomPanelState)
            }
        }
    }

    // MARK: - Add Worktree Button

    private var addWorktreeButton: some View {
        Button {
            coordinator.showAddWorktreeSheet(store: worktreeStore, branch: nil)
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
