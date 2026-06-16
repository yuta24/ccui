import SwiftUI

struct SessionListSection: View {
    let worktree: Worktree
    let onResumeSession: (String) -> Void
    let onNewSession: () -> Void
    let onEvaluateSession: (WorktreeSessionEntry) -> Void
    var onJumpToWorktree: (() -> Void)?

    @Environment(WorktreeSessionStore.self) private var worktreeSessionStore
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(RepositoryStore.self) private var repositoryStore

    private var reversedSessions: [WorktreeSessionEntry] {
        (worktreeSessionStore.entries[worktree.path] ?? []).reversed()
    }

    private var repositoryName: String? {
        repositoryStore.repositories.first { $0.id == worktree.repositoryID }?.name
    }

    private var indicatorColor: Color {
        WorktreeRowView.indicatorColor(worktree: worktree, summary: claudeEventStore.agentSummary(for: worktree.path))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader

            if reversedSessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    sessionList
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(indicatorColor)
                    .frame(width: 4, height: 16)

                Text("Sessions")
                    .font(.uiCaption)
                    .foregroundStyle(Color.textPrimary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if let onJumpToWorktree {
                    Button(action: onJumpToWorktree) {
                        Image(systemName: "location")
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.textSecondary)
                    .help("Show in repository list")
                    .accessibilityLabel("Show in repository list")
                }

                Button(action: onNewSession) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .medium))
                        Text("New")
                            .font(.uiCaption)
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accent)
            }

            HStack(spacing: 4) {
                if let repositoryName {
                    Text(repositoryName)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .medium))
                }
                Text(worktree.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.uiCaption)
            .foregroundStyle(Color.textTertiary)
            .padding(.leading, 10)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Button(action: onNewSession) {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 10))
                Text("New Session")
                    .font(.uiCaption)
            }
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session List

    private var sessionList: some View {
        let runningSessionId = terminalSessionStore.currentSessionId(for: worktree.path)
        return VStack(spacing: 0) {
            ForEach(reversedSessions, id: \.sessionId) { entry in
                SessionAnnotationRow(
                    entry: entry,
                    worktreePath: worktree.path,
                    isRunning: runningSessionId == entry.sessionId,
                    onResume: { onResumeSession(entry.sessionId) },
                    onDelete: {
                        terminalSessionStore.removeIfMatches(path: worktree.path, sessionId: entry.sessionId)
                        worktreeSessionStore.removeSession(for: worktree.path, sessionId: entry.sessionId)
                    },
                    onEvaluate: { onEvaluateSession(entry) }
                )
            }
        }
    }
}
