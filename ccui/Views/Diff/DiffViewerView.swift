import SwiftUI

struct DiffViewerView: View {
    @Environment(DiffStore.self) private var store
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    let repositoryPath: String
    let worktreePath: String

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            switch store.state {
            case .idle:
                idleView
            case .loading:
                PulsingDotsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.surfacePrimary)
            case .loaded(let entries):
                if entries.isEmpty {
                    placeholderView(
                        icon: "checkmark.circle",
                        message: "No changes"
                    )
                } else {
                    diffSplitView(entries: entries)
                }
            case .error(let message):
                placeholderView(icon: "exclamationmark.triangle", message: message)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("Changes")
                .sectionHeader()

            Spacer()

            Button {
                Task { await store.load(repositoryPath: repositoryPath) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Refresh diff")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.surfacePrimary)
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)
            Text("Open panel to load diff")
                .font(.uiLabel)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }

    private func placeholderView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)
            Text(message)
                .font(.uiLabel)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }

    // MARK: - Unified Diff View

    private var sendToAgentAction: ((String) -> Void)? {
        // Return nil early if no session exists at render time (hides the comment button).
        // The closure re-checks at call time so a session that dies after render is caught.
        guard terminalSessionStore.session(forWorktreePath: worktreePath) != nil else { return nil }
        let store = terminalSessionStore
        let path = worktreePath
        return { text in
            guard let session = store.session(forWorktreePath: path),
                  session.isProcessRunning else { return }
            session.pasteText(text)
        }
    }

    private func diffSplitView(entries: [DiffFileEntry]) -> some View {
        let sendAction = sendToAgentAction
        return GeometryReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(entries) { entry in
                        DiffFileSection(
                            entry: entry,
                            contentWidth: proxy.size.width,
                            onSendToAgent: sendAction
                        )
                    }
                }
            }
            .background(Color.surfacePrimary)
        }
    }
}
