import SwiftUI

struct AgentMainContentView: View {
    let worktree: Worktree
    @Environment(DetailUIState.self) private var uiState
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(BottomPanelState.self) private var bottomPanelState
    @Environment(WorktreeSessionStore.self) private var worktreeSessionStore

    var body: some View {
        AgentSplitViewRepresentable(
            worktree: worktree,
            isSplit: uiState.agentLayoutMode == .split,
            webViewTabsStore: uiState.webViewTabsStore,
            terminalSessionStore: terminalSessionStore,
            bottomPanelState: bottomPanelState,
            worktreeSessionStore: worktreeSessionStore
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - NSViewControllerRepresentable

private struct AgentSplitViewRepresentable: NSViewControllerRepresentable {
    let worktree: Worktree
    let isSplit: Bool
    let webViewTabsStore: WebViewTabsStore
    let terminalSessionStore: TerminalSessionStore
    let bottomPanelState: BottomPanelState
    let worktreeSessionStore: WorktreeSessionStore

    func makeNSViewController(context: Context) -> AgentSplitViewController {
        AgentSplitViewController(
            worktree: worktree,
            isSplit: isSplit,
            webViewTabsStore: webViewTabsStore,
            terminalSessionStore: terminalSessionStore,
            bottomPanelState: bottomPanelState,
            worktreeSessionStore: worktreeSessionStore
        )
    }

    func updateNSViewController(_ controller: AgentSplitViewController, context: Context) {
        controller.update(
            worktree: worktree,
            isSplit: isSplit,
            webViewTabsStore: webViewTabsStore,
            terminalSessionStore: terminalSessionStore,
            bottomPanelState: bottomPanelState,
            worktreeSessionStore: worktreeSessionStore
        )
    }
}
