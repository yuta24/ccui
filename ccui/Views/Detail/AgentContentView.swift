import SwiftUI

struct AgentContentView: View {
    let worktree: Worktree
    @Environment(TerminalSessionStore.self) private var terminalSessionStore

    var body: some View {
        if let session = terminalSessionStore.session(for: worktree) {
            TerminalContainerView(session: session, isActive: true)
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
