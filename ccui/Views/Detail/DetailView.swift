import SwiftUI

struct DetailView: View {
    let worktree: Worktree
    let fileTreeStore: FileTreeStore?
    let fileOverlayStore: FileOverlayStore
    let codeViewerStore: CodeViewerStore
    let sessionComparisonStore: SessionComparisonStore
    @Environment(DiffStore.self) private var diffStore
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(WorktreeSessionStore.self) private var worktreeSessionStore
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(ShellSessionStore.self) private var shellSessionStore
    @State private var isTimelineVisible = false
    @State private var isStatsVisible = false
    @State private var isClaudeMdVisible = false
    @State private var isEvaluationVisible = false
    @State private var isHooksVisible = false
    @State private var isPermissionsVisible = false
    @State private var isBottomPanelExpanded = false
    @State private var bottomPanelHeight: CGFloat = 220
    @GestureState private var bottomPanelDragOffset: CGFloat = 0
    @State private var bottomPanelCursorPushed = false
    @State private var claudeMdStore = ClaudeMdStore()
    @State private var sessionEvaluationStore = SessionEvaluationStore()
    @State private var hooksStore = HooksStore()
    @State private var hookTestRunner = HookTestRunner()
    @State private var permissionsStore = PermissionsStore()
    @State private var reversedSessions: [WorktreeSessionEntry] = []

    var body: some View {
        let _ = fileOverlayStore.isVisible // establish @Observable tracking for onChange
        VStack(spacing: 0) {
            DetailTopBar(worktree: worktree, fileOverlayStore: fileOverlayStore, hasActiveSession: hasActiveSession, isTimelineVisible: $isTimelineVisible, isStatsVisible: $isStatsVisible, isClaudeMdVisible: $isClaudeMdVisible, isEvaluationVisible: $isEvaluationVisible, isHooksVisible: $isHooksVisible, isPermissionsVisible: $isPermissionsVisible)
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    terminalContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if isTimelineVisible {
                        TimelineView(worktreePath: worktree.path)
                    }
                    if isStatsVisible {
                        ToolStatsView(repositoryWorktreePaths: repositoryWorktreePaths)
                    }
                    if isClaudeMdVisible {
                        ClaudeMdPanelView(repositoryPath: repositoryPath, store: claudeMdStore)
                    }
                    if isEvaluationVisible {
                        SessionEvaluationView(store: sessionEvaluationStore, isVisible: $isEvaluationVisible)
                    }
                    if isHooksVisible {
                        HooksPanelView(worktreePath: worktree.path, store: hooksStore, testRunner: hookTestRunner)
                    }
                    if isPermissionsVisible {
                        PermissionsPanelView(worktreePath: worktree.path, store: permissionsStore)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isBottomPanelExpanded {
                    Rectangle()
                        .fill(Color.borderSubtle)
                        .frame(height: 1)
                        .contentShape(Rectangle().inset(by: -3))
                        .gesture(
                            DragGesture()
                                .updating($bottomPanelDragOffset) { value, state, _ in
                                    state = -value.translation.height
                                }
                                .onEnded { value in
                                    bottomPanelHeight = max(120, min(600, bottomPanelHeight - value.translation.height))
                                }
                        )
                        .onHover { hovering in
                            if hovering {
                                NSCursor.resizeUpDown.push()
                                bottomPanelCursorPushed = true
                            } else if bottomPanelCursorPushed {
                                NSCursor.pop()
                                bottomPanelCursorPushed = false
                            }
                        }
                        .onDisappear {
                            if bottomPanelCursorPushed {
                                NSCursor.pop()
                                bottomPanelCursorPushed = false
                            }
                        }
                }

                BottomTerminalPanelView(worktreePath: worktree.path, isExpanded: $isBottomPanelExpanded)
                    .frame(height: isBottomPanelExpanded ? max(120, min(600, bottomPanelHeight + bottomPanelDragOffset)) : nil)
            }
        }
        .onAppear {
            diffStore.reset()
            codeViewerStore.reset()
            startWatching()
            reversedSessions = (worktreeSessionStore.entries[worktree.path] ?? []).reversed()
        }
        .onDisappear {
            diffStore.stopWatching()
        }
        .onChange(of: worktree) { _, newWorktree in
            isTimelineVisible = false
            isStatsVisible = false
            isClaudeMdVisible = false
            isEvaluationVisible = false
            isHooksVisible = false
            isPermissionsVisible = false
            isBottomPanelExpanded = false
            bottomPanelHeight = 220
            claudeMdStore.reset()
            sessionEvaluationStore.close()
            hooksStore.reset()
            permissionsStore.reset()
            codeViewerStore.reset()
            reversedSessions = (worktreeSessionStore.entries[newWorktree.path] ?? []).reversed()
            diffStore.reset()
            fileOverlayStore.deselectFile()
            startWatching()
            if fileOverlayStore.isVisible {
                Task { await diffStore.load(repositoryPath: newWorktree.path) }
            }
        }
        .onChange(of: fileOverlayStore.isVisible) { _, isOpen in
            if isOpen, diffStore.needsLoad {
                Task { await diffStore.load(repositoryPath: worktree.path) }
            }
        }
        .onChange(of: worktreeSessionStore.entries[worktree.path]) { _, newEntries in
            reversedSessions = (newEntries ?? []).reversed()
        }
        .onChange(of: fileTreeStore?.selectedNode) { _, newValue in
            guard let node = newValue, !node.isDirectory else { return }
            fileOverlayStore.selectFile(node)
            fileOverlayStore.open()
            if diffStore.needsLoad {
                Task { await diffStore.load(repositoryPath: worktree.path) }
            }
        }
    }

    // MARK: - Session Actions

    private func resumeSession(sessionId: String) {
        Task {
            await terminalSessionStore.ensureSession(for: worktree, sessionId: sessionId, isResume: true)
            setupSessionHandlers(sessionId: sessionId)
        }
    }

    private func newSession() {
        let sessionId = worktreeSessionStore.createSession(for: worktree.path)
        Task {
            await terminalSessionStore.ensureSession(for: worktree, sessionId: sessionId, isResume: false)
            setupSessionHandlers(sessionId: sessionId)
        }
    }

    private func setupSessionHandlers(sessionId: String) {
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

    private func startWatching() {
        diffStore.startWatching(repositoryPath: worktree.path) { [fileOverlayStore] in
            fileOverlayStore.isVisible
        }
    }

    // MARK: - Terminal Content

    private var repositoryPath: String {
        coordinator.worktreeStores[worktree.repositoryID]?.repositoryPath ?? worktree.path
    }

    private var repositoryWorktreePaths: Set<String> {
        let repoID = worktree.repositoryID
        let worktrees = coordinator.worktreeStores[repoID]?.worktrees ?? []
        return Set(worktrees.map(\.path))
    }

    private var hasActiveSession: Bool {
        terminalSessionStore.session(for: worktree) != nil
    }

    private var terminalContent: some View {
        Group {
            if let session = terminalSessionStore.session(for: worktree) {
                TerminalContainerView(session: session, isActive: true)
            } else {
                sessionLauncherView
            }
        }
        .onChange(of: hasActiveSession) { _, active in
            if !active {
                isTimelineVisible = false
            }
        }
    }

    private var sessionLauncherView: some View {
        let sessions = reversedSessions
        return VStack(spacing: 0) {
            if sessions.isEmpty {
                Spacer()
                Image(systemName: "terminal")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.textTertiary)
                VStack(spacing: 12) {
                    Text("No sessions")
                        .font(.uiLabel)
                        .foregroundStyle(Color.textSecondary)
                    Button(action: newSession) {
                        Text("New Session")
                            .font(.uiCaption)
                            .foregroundStyle(Color.surfaceBase)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Sessions")
                            .sectionHeader()
                        Spacer()
                        Button(action: newSession) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("New")
                                    .font(.uiCaption)
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Rectangle()
                        .fill(Color.borderSubtle)
                        .frame(height: 1)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(sessions, id: \.sessionId) { entry in
                                SessionAnnotationRow(
                                    entry: entry,
                                    worktreePath: worktree.path,
                                    onResume: { resumeSession(sessionId: entry.sessionId) },
                                    onDelete: { worktreeSessionStore.removeSession(for: worktree.path, sessionId: entry.sessionId) },
                                    onEvaluate: {
                                        if let session = claudeEventStore.sessions[worktree.path]?[entry.sessionId] {
                                            sessionEvaluationStore.open(session: session, title: entry.title)
                                            isEvaluationVisible = true
                                        }
                                    },
                                    onCompare: { otherEntry in
                                        if let sessionA = claudeEventStore.sessions[worktree.path]?[entry.sessionId],
                                           let sessionB = claudeEventStore.sessions[worktree.path]?[otherEntry.sessionId] {
                                            sessionComparisonStore.open(sessionA: sessionA, titleA: entry.title, sessionB: sessionB, titleB: otherEntry.title)
                                        }
                                    },
                                    availableSessions: sessions.filter {
                                        $0.sessionId != entry.sessionId
                                            && claudeEventStore.sessions[worktree.path]?[$0.sessionId] != nil
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }


}
