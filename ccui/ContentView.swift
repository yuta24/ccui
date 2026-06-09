import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(ShellSessionStore.self) private var shellSessionStore
    @Environment(DetailUIState.self) private var detailUIState
    @Environment(SessionComparisonStore.self) private var sessionComparisonStore
    @Environment(BottomPanelState.self) private var bottomPanelState
    @Environment(QuickOpenStore.self) private var quickOpenStore
    @Environment(SearchStore.self) private var searchStore
    @State private var fileOverlayStore = FileOverlayStore()
    @State private var codeViewerStore = CodeViewerStore()

    var body: some View {
        @Bindable var coordinator = coordinator

        ZStack {
            VStack(spacing: 0) {
                if let worktree = coordinator.selectedWorktree {
                    DetailView(
                        worktree: worktree,
                        fileTreeStore: coordinator.fileTreeStore,
                        fileOverlayStore: fileOverlayStore,
                        codeViewerStore: codeViewerStore,
                        searchStore: searchStore,
                        sessionComparisonStore: sessionComparisonStore
                    )
                    .environment(detailUIState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    emptyState
                }
            }

            if sessionComparisonStore.isVisible {
                SessionComparisonView(store: sessionComparisonStore)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            if quickOpenStore.isVisible, let worktree = coordinator.selectedWorktree {
                QuickOpenPaletteView(
                    quickOpenStore: quickOpenStore,
                    fileOverlayStore: fileOverlayStore,
                    fileTreeStore: coordinator.fileTreeStore,
                    repositoryPath: worktree.path
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: sessionComparisonStore.isVisible)
        .animation(.easeInOut(duration: 0.15), value: quickOpenStore.isVisible)
        .onChange(of: fileOverlayStore.selectedFile) { _, newFile in
            if newFile != nil, detailUIState.contentMode != .files {
                detailUIState.contentMode = .files
            }
        }
        .onChange(of: coordinator.selectedWorktree) { _, newValue in
            detailUIState.resetForWorktreeChange()
            sessionComparisonStore.close()
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
            guard let wt = coordinator.selectedWorktree else { return }
            // 選択中の worktree で新しい attention / 完了が発生した場合、見ているとみなして即座に既読化する。
            // ただし permissionRequest 待ち中はバッジを消さない（ユーザーがまだ応答していない）。
            let summary = claudeEventStore.agentSummary(for: wt.path)
            guard summary.activity != .waitingForUser else { return }
            if summary.pendingAttentionCount > 0 || summary.hasUnacknowledgedFinished {
                claudeEventStore.acknowledge(for: wt.path)
            }
        }
        .onChange(of: store.repositories) { _, newValue in
            coordinator.syncWorktreeStores(
                with: newValue,
                terminalSessionStore: terminalSessionStore,
                shellSessionStore: shellSessionStore,
                claudeEventStore: claudeEventStore,
                bottomPanelState: bottomPanelState
            )
        }
        .onAppear {
            coordinator.ensureWorktreeStores(
                for: store.repositories,
                claudeEventStore: claudeEventStore
            )
            if let wt = coordinator.selectedWorktree {
                quickOpenStore.buildIndex(rootPath: wt.path)
                searchStore.buildIndex(rootPath: wt.path)
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
    }
}
