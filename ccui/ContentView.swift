import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(WorktreeLifecycleCoordinator.self) private var worktreeLifecycleCoordinator
    @Environment(DetailUIState.self) private var detailUIState
    @Environment(QuickOpenStore.self) private var quickOpenStore
    @Environment(SearchStore.self) private var searchStore
    @State private var fileOverlayStore = FileOverlayStore()
    @State private var codeViewerStore = CodeViewerStore()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if let worktree = navigationStore.selectedWorktree {
                    DetailView(
                        worktree: worktree,
                        fileTreeStore: navigationStore.fileTreeStore,
                        fileOverlayStore: fileOverlayStore,
                        codeViewerStore: codeViewerStore,
                        searchStore: searchStore
                    )
                    .environment(detailUIState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    emptyState
                }
            }

            if quickOpenStore.isVisible, let worktree = navigationStore.selectedWorktree {
                QuickOpenPaletteView(
                    quickOpenStore: quickOpenStore,
                    fileOverlayStore: fileOverlayStore,
                    fileTreeStore: navigationStore.fileTreeStore,
                    repositoryPath: worktree.path
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: quickOpenStore.isVisible)
        .onChange(of: fileOverlayStore.selectedFile) { _, newFile in
            if newFile != nil, detailUIState.contentMode != .files {
                detailUIState.contentMode = .files
            }
        }
        .onChange(of: navigationStore.selectedWorktree) { _, newValue in
            detailUIState.resetForWorktreeChange()
            quickOpenStore.close()
            searchStore.deactivate()
            if let wt = newValue {
                claudeEventStore.acknowledge(for: wt.path)
                quickOpenStore.buildIndex(rootPath: wt.path)
                searchStore.buildIndex(rootPath: wt.path)
            } else {
                quickOpenStore.clearIndex()
                searchStore.clearIndex()
            }
        }
        .onChange(of: claudeEventStore.eventCounter) { _, _ in
            guard let wt = navigationStore.selectedWorktree else { return }
            // 選択中の worktree で新しい attention / 完了が発生した場合、見ているとみなして即座に既読化する。
            // ただし permissionRequest 待ち中はバッジを消さない（ユーザーがまだ応答していない）。
            let summary = claudeEventStore.agentSummary(for: wt.path)
            guard summary.activity != .waitingForUser else { return }
            if summary.pendingAttentionCount > 0 || summary.hasUnacknowledgedFinished {
                claudeEventStore.acknowledge(for: wt.path)
            }
        }
        .onChange(of: store.repositories) { _, newValue in
            worktreeLifecycleCoordinator.syncWorktreeStores(with: newValue)
        }
        .onAppear {
            worktreeLifecycleCoordinator.ensureWorktreeStores(for: store.repositories)
            if let wt = navigationStore.selectedWorktree {
                quickOpenStore.buildIndex(rootPath: wt.path)
                searchStore.buildIndex(rootPath: wt.path)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.branch")
                .font(.emptyStateIconLarge)
                .foregroundStyle(Color.textTertiary)

            VStack(spacing: 6) {
                Text("Select a worktree")
                    .font(.uiLabel)
                    .foregroundStyle(Color.textSecondary)
                Text("Choose a worktree from the sidebar to begin")
                    .font(.uiCaption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }
}
