import SwiftUI

struct AgentMainContentView: View {
    let worktree: Worktree
    @Environment(DetailUIState.self) private var uiState
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(BottomPanelState.self) private var bottomPanelState

    var body: some View {
        AgentSplitViewRepresentable(
            worktree: worktree,
            isSplit: uiState.agentLayoutMode == .split,
            webViewStore: uiState.webViewStore,
            terminalSessionStore: terminalSessionStore,
            bottomPanelState: bottomPanelState
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - NSViewControllerRepresentable

private struct AgentSplitViewRepresentable: NSViewControllerRepresentable {
    let worktree: Worktree
    let isSplit: Bool
    let webViewStore: WebViewStore
    let terminalSessionStore: TerminalSessionStore
    let bottomPanelState: BottomPanelState

    func makeNSViewController(context: Context) -> AgentSplitViewController {
        AgentSplitViewController(
            worktree: worktree,
            isSplit: isSplit,
            webViewStore: webViewStore,
            terminalSessionStore: terminalSessionStore,
            bottomPanelState: bottomPanelState
        )
    }

    func updateNSViewController(_ controller: AgentSplitViewController, context: Context) {
        controller.update(
            worktree: worktree,
            isSplit: isSplit,
            webViewStore: webViewStore,
            terminalSessionStore: terminalSessionStore,
            bottomPanelState: bottomPanelState
        )
    }
}
