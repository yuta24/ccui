import SwiftUI

struct SidebarContainerView: View {
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(WorktreeSessionStore.self) private var worktreeSessionStore
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(DetailUIState.self) private var detailUIState
    @Environment(SessionComparisonStore.self) private var sessionComparisonStore

    var body: some View {
        SidebarView(
            onResumeSession: { sessionId in
                guard let worktree = coordinator.selectedWorktree else { return }
                detailUIState.contentMode = .agent
                Task {
                    await terminalSessionStore.ensureSession(for: worktree, sessionId: sessionId, isResume: true)
                    setupSessionHandlers(for: worktree, sessionId: sessionId)
                }
            },
            onNewSession: {
                guard let worktree = coordinator.selectedWorktree else { return }
                detailUIState.contentMode = .agent
                let sessionId = worktreeSessionStore.createSession(for: worktree.path)
                Task {
                    await terminalSessionStore.ensureSession(for: worktree, sessionId: sessionId, isResume: false)
                    setupSessionHandlers(for: worktree, sessionId: sessionId)
                }
            },
            onEvaluateSession: { entry in
                guard let worktree = coordinator.selectedWorktree else { return }
                if let session = claudeEventStore.sessions[worktree.path]?[entry.sessionId] {
                    detailUIState.sessionEvaluationStore.open(session: session, title: entry.title)
                    detailUIState.rightPanelTab = .eval
                    detailUIState.isRightPanelVisible = true
                    detailUIState.contentMode = .agent
                }
            },
            onCompareSession: { entryA, entryB in
                guard let worktree = coordinator.selectedWorktree else { return }
                if let sessionA = claudeEventStore.sessions[worktree.path]?[entryA.sessionId],
                   let sessionB = claudeEventStore.sessions[worktree.path]?[entryB.sessionId] {
                    sessionComparisonStore.open(sessionA: sessionA, titleA: entryA.title, sessionB: sessionB, titleB: entryB.title)
                }
            }
        )
        .floatingPanel()
    }

    private func setupSessionHandlers(for worktree: Worktree, sessionId: String) {
        let path = worktree.path
        if let session = terminalSessionStore.session(for: worktree) {
            session.onProcessTerminated = { [weak terminalSessionStore] in
                terminalSessionStore?.remove(for: path)
            }
            session.onTitleChanged = { [weak worktreeSessionStore] title in
                worktreeSessionStore?.updateTitle(for: path, sessionId: sessionId, title: title)
            }
        }
    }
}
