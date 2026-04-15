import SwiftUI

struct SessionListSection: View {
    let worktree: Worktree
    let onResumeSession: (String) -> Void
    let onNewSession: () -> Void
    let onEvaluateSession: (WorktreeSessionEntry) -> Void
    let onCompareSession: (WorktreeSessionEntry, WorktreeSessionEntry) -> Void

    @Environment(WorktreeSessionStore.self) private var worktreeSessionStore
    @Environment(ClaudeEventStore.self) private var claudeEventStore

    private var reversedSessions: [WorktreeSessionEntry] {
        (worktreeSessionStore.entries[worktree.path] ?? []).reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader

            if reversedSessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Text("Sessions")
                .font(.uiCaption)
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Spacer()

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
            .foregroundStyle(Color.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session List

    private var sessionList: some View {
        LazyVStack(spacing: 0) {
            ForEach(reversedSessions, id: \.sessionId) { entry in
                SessionAnnotationRow(
                    entry: entry,
                    worktreePath: worktree.path,
                    onResume: { onResumeSession(entry.sessionId) },
                    onDelete: { worktreeSessionStore.removeSession(for: worktree.path, sessionId: entry.sessionId) },
                    onEvaluate: { onEvaluateSession(entry) },
                    onCompare: { otherEntry in onCompareSession(entry, otherEntry) },
                    availableSessions: reversedSessions.filter {
                        $0.sessionId != entry.sessionId
                            && claudeEventStore.sessions[worktree.path]?[$0.sessionId] != nil
                    }
                )
            }
        }
    }
}
