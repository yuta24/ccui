import SwiftUI

struct AgentContentView: View {
    let worktree: Worktree
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(BottomPanelState.self) private var bottomPanelState

    var body: some View {
        if terminalSessionStore.session(for: worktree) != nil {
            AgentTerminalRepresentable(
                worktree: worktree,
                terminalSessionStore: terminalSessionStore,
                bottomPanelState: bottomPanelState
            )
        } else {
            emptyState
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "terminal")
                .font(.system(size: 32))
                .foregroundStyle(Color.textTertiary)
            VStack(spacing: 12) {
                Text("No active session")
                    .font(.uiLabel)
                    .foregroundStyle(Color.textSecondary)
                Text("Resume a session from the sidebar\nor start a new one")
                    .font(.uiCaption)
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }
}

// MARK: - NSViewControllerRepresentable

private struct AgentTerminalRepresentable: NSViewControllerRepresentable {
    let worktree: Worktree
    let terminalSessionStore: TerminalSessionStore
    let bottomPanelState: BottomPanelState

    func makeNSViewController(context: Context) -> AgentTerminalViewController {
        AgentTerminalViewController(
            worktree: worktree,
            terminalSessionStore: terminalSessionStore,
            bottomPanelState: bottomPanelState
        )
    }

    func updateNSViewController(_ controller: AgentTerminalViewController, context: Context) {
        controller.update(worktree: worktree)
    }
}
