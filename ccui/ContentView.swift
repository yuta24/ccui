import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(ShellSessionStore.self) private var shellSessionStore
    @Environment(WorktreeSessionStore.self) private var worktreeSessionStore
    @State private var sidebarWidth: CGFloat = 240
    @GestureState private var dragOffset: CGFloat = 0
    @State private var sidebarCursorPushed = false
    @State private var sidebarHandleHovered = false
    @State private var fileOverlayStore = FileOverlayStore()
    @State private var sessionComparisonStore = SessionComparisonStore()
    @State private var codeViewerStore = CodeViewerStore()
    @State private var diffStore = DiffStore()
    @State private var quickOpenStore = QuickOpenStore()
    @State private var searchStore = SearchStore()
    @State private var detailUIState = DetailUIState()
    @State private var showingConfiguration = false
    @State private var escMonitor: Any?

    var body: some View {
        @Bindable var coordinator = coordinator

        ZStack {
            VStack(spacing: 0) {
                AgentDashboardBar(
                    showingConfiguration: $showingConfiguration
                )

                HStack(spacing: 0) {
                    sidebarSection
                    sidebarResizeHandle

                    if let worktree = coordinator.selectedWorktree {
                        DetailView(
                            worktree: worktree,
                            fileTreeStore: coordinator.fileTreeStore,
                            fileOverlayStore: fileOverlayStore,
                            codeViewerStore: codeViewerStore,
                            searchStore: searchStore,
                            sessionComparisonStore: sessionComparisonStore
                        )
                        .environment(detailUIState)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.surfacePrimary)
                    } else {
                        emptyState
                    }
                }
            }
            .background(Color.surfaceBase)

            if sessionComparisonStore.isVisible {
                SessionComparisonView(store: sessionComparisonStore)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            if quickOpenStore.isVisible, let worktree = coordinator.selectedWorktree {
                QuickOpenPaletteView(
                    quickOpenStore: quickOpenStore,
                    fileOverlayStore: fileOverlayStore,
                    fileTreeStore: coordinator.fileTreeStore,
                    repositoryPath: worktree.path
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .environment(diffStore)
        .animation(.easeInOut(duration: 0.2), value: sessionComparisonStore.isVisible)
        .animation(.easeInOut(duration: 0.15), value: quickOpenStore.isVisible)
        .onChange(of: fileOverlayStore.selectedFile) { _, newFile in
            if newFile != nil, detailUIState.contentMode != .files {
                detailUIState.contentMode = .files
            }
        }
        .onChange(of: coordinator.selectedWorktree) { _, newValue in
            detailUIState.resetForWorktreeChange()
            sessionComparisonStore.close()
            quickOpenStore.close()
            searchStore.deactivate()
            showingConfiguration = false
            if let wt = newValue {
                claudeEventStore.acknowledge(for: wt.path)
                quickOpenStore.buildIndex(rootPath: wt.path)
                searchStore.buildIndex(rootPath: wt.path)
            } else {
                quickOpenStore.clearIndex()
                searchStore.clearIndex()
            }
        }
        .onChange(of: claudeEventStore.sessions) { _, _ in
            if let wt = coordinator.selectedWorktree, claudeEventStore.hasUnacknowledged(for: wt.path) {
                claudeEventStore.acknowledge(for: wt.path)
            }
        }
        .onChange(of: store.repositories) { _, newValue in
            coordinator.syncWorktreeStores(
                with: newValue,
                terminalSessionStore: terminalSessionStore,
                shellSessionStore: shellSessionStore,
                claudeEventStore: claudeEventStore
            )
        }
        .sheet(item: $coordinator.showingAddWorktree) { wtStore in
            AddWorktreeView(
                worktreeStore: wtStore,
                repositoryPath: wtStore.repositoryPath,
                initialBaseBranch: coordinator.initialBaseBranch
            )
        }
        .sheet(isPresented: Binding(
            get: { showingConfiguration && coordinator.selectedWorktree != nil },
            set: { showingConfiguration = $0 }
        )) {
            if let worktree = coordinator.selectedWorktree {
                let repoPath = coordinator.worktreeStores[worktree.repositoryID]?.repositoryPath ?? worktree.path
                ConfigurationSheet(
                    worktreePath: worktree.path,
                    repositoryPath: repoPath,
                    isPresented: $showingConfiguration
                )
            }
        }
        .alert("Uncommitted Changes", isPresented: $coordinator.showForceDeleteAlert) {
            Button("Force Delete", role: .destructive) {
                coordinator.forceDeleteWorktree(terminalSessionStore: terminalSessionStore, shellSessionStore: shellSessionStore)
            }
            Button("Cancel", role: .cancel) {
                coordinator.forceDeleteTarget = nil
            }
        } message: {
            Text("This worktree has uncommitted changes. Force delete will discard them.")
        }
        .onAppear {
            coordinator.ensureWorktreeStores(
                for: store.repositories,
                claudeEventStore: claudeEventStore
            )
            if let wt = coordinator.selectedWorktree {
                quickOpenStore.buildIndex(rootPath: wt.path)
                searchStore.buildIndex(rootPath: wt.path)
            }
            installKeyMonitor()
        }
        .onDisappear {
            if let monitor = escMonitor {
                NSEvent.removeMonitor(monitor)
                escMonitor = nil
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarSection: some View {
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
        .frame(width: max(180, min(400, sidebarWidth + dragOffset)))
        .background(Color.surfaceBase)
    }

    private var sidebarResizeHandle: some View {
        Rectangle()
            .fill(sidebarHandleHovered ? Color.borderStrong : Color.borderSubtle)
            .frame(width: sidebarHandleHovered ? 3 : 1)
            .animation(.easeInOut(duration: 0.15), value: sidebarHandleHovered)
            .contentShape(Rectangle().inset(by: -3))
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        sidebarWidth = max(180, min(400, sidebarWidth + value.translation.width))
                    }
            )
            .onHover { hovering in
                sidebarHandleHovered = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                    sidebarCursorPushed = true
                } else if sidebarCursorPushed {
                    NSCursor.pop()
                    sidebarCursorPushed = false
                }
            }
    }

    // MARK: - Session Handlers

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

    // MARK: - Key Monitor

    private func installKeyMonitor() {
        if let existing = escMonitor {
            NSEvent.removeMonitor(existing)
            escMonitor = nil
        }

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [detailUIState, quickOpenStore, searchStore, coordinator, sessionComparisonStore] event in
            // Cmd+Shift+E → toggle Agent/Files mode
            if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && event.keyCode == 14 {
                guard coordinator.selectedWorktree != nil else { return event }
                detailUIState.contentMode = detailUIState.contentMode == .agent ? .files : .agent
                return nil
            }

            // Cmd+I → toggle Right Panel (Agent mode only)
            if event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) && event.keyCode == 34 {
                guard coordinator.selectedWorktree != nil else { return event }
                guard detailUIState.contentMode == .agent else { return event }
                detailUIState.isRightPanelVisible.toggle()
                return nil
            }

            // Cmd+F → file search (switch to Files mode)
            if event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) && event.keyCode == 3 {
                guard coordinator.selectedWorktree != nil else { return event }
                quickOpenStore.close()
                detailUIState.contentMode = .files
                searchStore.activate(mode: .files)
                return nil
            }

            // Cmd+Shift+F → content search (switch to Files mode)
            if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && event.keyCode == 3 {
                guard coordinator.selectedWorktree != nil else { return event }
                quickOpenStore.close()
                detailUIState.contentMode = .files
                searchStore.activate(mode: .content)
                return nil
            }

            // Cmd+P → quick open
            if event.modifierFlags.contains(.command) && event.keyCode == 35 {
                guard coordinator.selectedWorktree != nil else { return event }
                if !quickOpenStore.isVisible {
                    searchStore.deactivate()
                    quickOpenStore.open()
                }
                return nil
            }

            // Esc
            if event.keyCode == 53 {
                if sessionComparisonStore.isVisible {
                    sessionComparisonStore.close()
                    return nil
                }
                if quickOpenStore.isVisible {
                    quickOpenStore.close()
                    return nil
                }
                if searchStore.isActive {
                    searchStore.deactivate()
                    return nil
                }
            }

            return event
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)

            Text("Select a worktree")
                .font(.uiLabel)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }
}
