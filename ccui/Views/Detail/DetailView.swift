import SwiftUI

struct DetailView: View {
    let worktree: Worktree
    let fileTreeStore: FileTreeStore?
    let fileOverlayStore: FileOverlayStore
    let codeViewerStore: CodeViewerStore
    let searchStore: SearchStore
    @Environment(DetailUIState.self) private var uiState
    @Environment(DiffStore.self) private var diffStore
    @Environment(TerminalSessionStore.self) private var terminalSessionStore


    var body: some View {
        mainContent
            .onAppear {
                diffStore.reset()
                codeViewerStore.reset()
                startWatching()
            }
            .onDisappear {
                diffStore.stopWatching()
            }
            .onChange(of: worktree) { _, _ in
                codeViewerStore.reset()
                diffStore.reset()
                fileOverlayStore.deselectFile()
                startWatching()
            }
            .onChange(of: terminalSessionStore.session(for: worktree) != nil) { _, hasSession in
                if !hasSession {
                    uiState.isRightPanelVisible = false
                }
            }
            .onChange(of: uiState.contentMode) { _, newMode in
                if newMode == .files, diffStore.needsLoad {
                    Task { await diffStore.load(repositoryPath: worktree.path) }
                }
            }
            .onChange(of: fileTreeStore?.selectedNode) { _, newValue in
                guard let node = newValue, !node.isDirectory else { return }
                fileOverlayStore.selectFile(node)
                uiState.contentMode = .files
                if diffStore.needsLoad {
                    Task { await diffStore.load(repositoryPath: worktree.path) }
                }
            }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch uiState.contentMode {
        case .agent:
            AgentMainContentView(worktree: worktree)

        case .files:
            FilesContentView(
                fileTreeStore: fileTreeStore,
                fileOverlayStore: fileOverlayStore,
                codeViewerStore: codeViewerStore,
                searchStore: searchStore,
                repositoryPath: worktree.path
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Diff Watching

    private func startWatching() {
        let uiState = uiState
        diffStore.startWatching(repositoryPath: worktree.path) {
            uiState.contentMode == .files || uiState.isRightPanelVisible
        }
    }
}
