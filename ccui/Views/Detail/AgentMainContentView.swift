import SwiftUI

struct AgentMainContentView: View {
    let worktree: Worktree
    @Environment(DetailUIState.self) private var uiState

    var body: some View {
        switch uiState.agentLayoutMode {
        case .full:
            AgentContentView(worktree: worktree)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .split:
            HSplitView {
                AgentContentView(worktree: worktree)
                    .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity, maxHeight: .infinity)

                WebViewPanelView(worktree: worktree, store: uiState.webViewStore)
                    .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
