import SwiftUI

struct AgentContentView: View {
    let worktree: Worktree
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(BottomPanelState.self) private var bottomPanelState
    @Environment(WorktreeSessionStore.self) private var worktreeSessionStore

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
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "terminal")
                .font(.emptyStateIconLarge)
                .foregroundStyle(Color.textTertiary)
            VStack(spacing: 14) {
                Text("No active session")
                    .font(.uiLabel)
                    .foregroundStyle(Color.textSecondary)

                Button(action: startNewSession) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.iconSmall)
                        Text("New Session")
                            .font(.uiCaption)
                    }
                    .foregroundStyle(Color.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.accentSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.inputCornerRadius))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }

    // MARK: - New Session

    private func startNewSession() {
        let sessionId = worktreeSessionStore.createSession(for: worktree.path)
        Task {
            await terminalSessionStore.ensureSession(
                for: worktree,
                sessionId: sessionId,
                isResume: false,
                configureHandlers: TerminalSessionStore.makeHandlerConfigurator(
                    worktreePath: worktree.path,
                    sessionId: sessionId,
                    terminalSessionStore: terminalSessionStore,
                    worktreeSessionStore: worktreeSessionStore
                )
            )
        }
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
