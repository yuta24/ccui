import SwiftUI

struct SidebarContainerView: View {
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(WorktreeSessionStore.self) private var worktreeSessionStore
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(WorktreeLifecycleCoordinator.self) private var worktreeLifecycleCoordinator
    @Environment(DetailUIState.self) private var detailUIState
    @Environment(SessionComparisonStore.self) private var sessionComparisonStore

    /// 実行中セッションを置き換える launch を確認待ちにする。
    /// 確認中に選択 worktree が変わっても要求時点の対象を保つため worktree をスナップショットで保持する。
    private struct PendingLaunch {
        let worktree: Worktree
        let sessionId: String
        let isResume: Bool
    }

    @State private var pendingLaunch: PendingLaunch?
    @State private var pendingNewSessionWorktree: Worktree?

    var body: some View {
        SidebarView(
            onResumeSession: { sessionId in
                guard let worktree = navigationStore.selectedWorktree else { return }
                requestLaunch(PendingLaunch(worktree: worktree, sessionId: sessionId, isResume: true))
            },
            onNewSession: {
                guard let worktree = navigationStore.selectedWorktree else { return }
                if terminalSessionStore.session(for: worktree)?.isProcessRunning == true {
                    pendingNewSessionWorktree = worktree
                } else {
                    startNewSession(in: worktree)
                }
            },
            onEvaluateSession: { entry in
                guard let worktree = navigationStore.selectedWorktree else { return }
                if let session = claudeEventStore.sessions[worktree.path]?[entry.sessionId] {
                    detailUIState.sessionEvaluationStore.open(session: session, title: entry.title)
                    detailUIState.rightPanelTab = .eval
                    detailUIState.isRightPanelVisible = true
                    detailUIState.contentMode = .agent
                }
            },
            onCompareSession: { entryA, entryB in
                guard let worktree = navigationStore.selectedWorktree else { return }
                if let sessionA = claudeEventStore.sessions[worktree.path]?[entryA.sessionId],
                   let sessionB = claudeEventStore.sessions[worktree.path]?[entryB.sessionId] {
                    sessionComparisonStore.open(sessionA: sessionA, titleA: entryA.title, sessionB: sessionB, titleB: entryB.title)
                }
            }
        )
        .confirmationDialog(
            "Switch session?",
            isPresented: Binding(
                get: { pendingLaunch != nil },
                set: { if !$0 { pendingLaunch = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Switch", role: .destructive) {
                guard let pendingLaunch else { return }
                self.pendingLaunch = nil
                resumeSession(pendingLaunch.sessionId, in: pendingLaunch.worktree)
            }
            Button("Cancel", role: .cancel) { pendingLaunch = nil }
        } message: {
            Text("The currently running Claude Code session in this worktree will be stopped. Unsaved progress in that session may be lost.")
        }
        .confirmationDialog(
            "Start a new session?",
            isPresented: Binding(
                get: { pendingNewSessionWorktree != nil },
                set: { if !$0 { pendingNewSessionWorktree = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Start New Session", role: .destructive) {
                guard let worktree = pendingNewSessionWorktree else { return }
                pendingNewSessionWorktree = nil
                startNewSession(in: worktree)
            }
            Button("Cancel", role: .cancel) { pendingNewSessionWorktree = nil }
        } message: {
            Text("The currently running Claude Code session in this worktree will be stopped. Unsaved progress in that session may be lost.")
        }
        .onChange(of: terminalSessionStore.lastLaunchFailure) { _, failure in
            guard let failure else { return }
            presentLaunchFailure(failure)
            terminalSessionStore.acknowledgeLaunchFailure()
        }
    }

    // MARK: - Launch helpers

    private func requestLaunch(_ launch: PendingLaunch) {
        if terminalSessionStore.hasRunningSession(for: launch.worktree.path, otherThan: launch.sessionId) {
            pendingLaunch = launch
        } else {
            resumeSession(launch.sessionId, in: launch.worktree)
        }
    }

    private func resumeSession(_ sessionId: String, in worktree: Worktree) {
        detailUIState.contentMode = .agent
        Task {
            await terminalSessionStore.ensureSession(
                for: worktree,
                sessionId: sessionId,
                isResume: true,
                configureHandlers: makeHandlerConfigurator(worktreePath: worktree.path, sessionId: sessionId)
            )
        }
    }

    private func startNewSession(in worktree: Worktree) {
        detailUIState.contentMode = .agent
        let sessionId = worktreeSessionStore.createSession(for: worktree.path)
        Task {
            await terminalSessionStore.ensureSession(
                for: worktree,
                sessionId: sessionId,
                isResume: false,
                configureHandlers: makeHandlerConfigurator(worktreePath: worktree.path, sessionId: sessionId)
            )
        }
    }

    private func presentLaunchFailure(_ failure: TerminalSessionStore.LaunchFailure) {
        let worktreeName = (failure.worktreePath as NSString).lastPathComponent
        let codeSuffix = failure.exitCode.map { " (exit code \($0))" } ?? ""
        worktreeLifecycleCoordinator.errorMessage = failure.isResume
            ? "Couldn't resume the session in \(worktreeName)\(codeSuffix). It may no longer be available to resume."
            : "Couldn't start Claude Code in \(worktreeName)\(codeSuffix). Check that the `claude` CLI is installed and on your PATH."
        worktreeLifecycleCoordinator.isErrorAlertPresented = true
    }

    private func makeHandlerConfigurator(worktreePath: String, sessionId: String) -> (any TerminalSession) -> Void {
        let terminalStore = terminalSessionStore
        let worktreeStore = worktreeSessionStore
        return { session in
            session.onProcessTerminated = { [weak terminalStore] _ in
                terminalStore?.removeIfMatches(path: worktreePath, sessionId: sessionId)
            }
            session.onTitleChanged = { [weak worktreeStore] title in
                worktreeStore?.updateTitle(for: worktreePath, sessionId: sessionId, title: title)
            }
        }
    }
}
