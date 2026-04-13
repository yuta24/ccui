import SwiftUI

struct DetailView: View {
    let worktree: Worktree
    let fileTreeStore: FileTreeStore?
    let fileOverlayStore: FileOverlayStore
    let codeViewerStore: CodeViewerStore
    @Environment(DiffStore.self) private var diffStore
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(WorktreeSessionStore.self) private var worktreeSessionStore
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(ShellSessionStore.self) private var shellSessionStore
    @State private var isTimelineVisible = false
    @State private var isStatsVisible = false
    @State private var isClaudeMdVisible = false
    @State private var isBottomPanelExpanded = false
    @State private var bottomPanelHeight: CGFloat = 220
    @GestureState private var bottomPanelDragOffset: CGFloat = 0
    @State private var bottomPanelCursorPushed = false
    @State private var claudeMdStore = ClaudeMdStore()

    var body: some View {
        let _ = fileOverlayStore.isVisible // establish @Observable tracking for onChange
        VStack(spacing: 0) {
            DetailTopBar(worktree: worktree, fileOverlayStore: fileOverlayStore, hasActiveSession: hasActiveSession, isTimelineVisible: $isTimelineVisible, isStatsVisible: $isStatsVisible, isClaudeMdVisible: $isClaudeMdVisible)
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
        }
        .onDisappear {
            diffStore.stopWatching()
        }
        .onChange(of: worktree) { _, newWorktree in
            isTimelineVisible = false
            isStatsVisible = false
            isClaudeMdVisible = false
            isBottomPanelExpanded = false
            bottomPanelHeight = 220
            claudeMdStore.reset()
            codeViewerStore.reset()
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
        let sessions = worktreeSessionStore.entries[worktree.path] ?? []
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
                            ForEach(sessions.reversed(), id: \.sessionId) { entry in
                                sessionRow(entry: entry)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }

    private func sessionRow(entry: WorktreeSessionEntry) -> some View {
        Button {
            resumeSession(sessionId: entry.sessionId)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "terminal")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title ?? String(entry.sessionId.prefix(8)))
                        .font(.uiLabel)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(entry.sessionId.prefix(8))
                            .font(.uiCaptionMono)
                            .foregroundStyle(Color.textTertiary)
                        Text("·")
                            .foregroundStyle(Color.textTertiary)
                        Text(entry.createdAt, style: .date)
                            .font(.uiCaption)
                            .foregroundStyle(Color.textTertiary)
                        Text(entry.createdAt, style: .time)
                            .font(.uiCaption)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.surfacePrimary)
        .contextMenu {
            Button(role: .destructive) {
                worktreeSessionStore.removeSession(for: worktree.path, sessionId: entry.sessionId)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

}
