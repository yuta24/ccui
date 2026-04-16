import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(ShellSessionStore.self) private var shellSessionStore
    @Environment(WorktreeSessionStore.self) private var worktreeSessionStore
    @Environment(DetailUIState.self) private var detailUIState
    @Environment(SessionComparisonStore.self) private var sessionComparisonStore
    @Environment(BottomPanelState.self) private var bottomPanelState
    @State private var fileOverlayStore = FileOverlayStore()
    @State private var codeViewerStore = CodeViewerStore()
    @State private var quickOpenStore = QuickOpenStore()
    @State private var searchStore = SearchStore()
    @State private var escMonitor: Any?

    var body: some View {
        @Bindable var coordinator = coordinator

        ZStack {
            VStack(spacing: 0) {
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
            bottomPanelState.collapse()
            if let wt = newValue {
                claudeEventStore.acknowledge(for: wt.path)
                quickOpenStore.buildIndex(rootPath: wt.path)
                searchStore.buildIndex(rootPath: wt.path)
            } else {
                quickOpenStore.clearIndex()
                searchStore.clearIndex()
            }
        }
        .onChange(of: claudeEventStore.sessions) { _, newSessions in
            guard let wt = coordinator.selectedWorktree,
                  let worktreeSessions = newSessions[wt.path] else { return }
            let cutoff = claudeEventStore.acknowledgedUpTo[wt.path]
            let hasNew = worktreeSessions.values.contains { session in
                guard let lastEvent = session.lastEventAt else { return false }
                let isTerminalState = session.state == .done || { if case .notified = session.state { return true }; return false }()
                guard isTerminalState else { return false }
                if let cutoff { return lastEvent > cutoff }
                return true
            }
            if hasNew {
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
            get: { detailUIState.showingConfiguration && coordinator.selectedWorktree != nil },
            set: { detailUIState.showingConfiguration = $0 }
        )) {
            if let worktree = coordinator.selectedWorktree {
                let repoPath = coordinator.worktreeStores[worktree.repositoryID]?.repositoryPath ?? worktree.path
                ConfigurationSheet(
                    worktreePath: worktree.path,
                    repositoryPath: repoPath,
                    isPresented: Binding(
                        get: { detailUIState.showingConfiguration },
                        set: { detailUIState.showingConfiguration = $0 }
                    )
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
        .alert("Error", isPresented: $coordinator.showErrorAlert) {
            Button("OK", role: .cancel) {
                coordinator.errorMessage = nil
            }
        } message: {
            Text(coordinator.errorMessage ?? "An unknown error occurred.")
        }
        .alert("Error", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.clearError() } }
        )) {
            Button("OK", role: .cancel) {
                store.clearError()
            }
        } message: {
            Text(store.lastError ?? "An unknown error occurred.")
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

    // MARK: - Key Monitor

    private func installKeyMonitor() {
        if let existing = escMonitor {
            NSEvent.removeMonitor(existing)
            escMonitor = nil
        }

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [detailUIState, quickOpenStore, searchStore, coordinator, sessionComparisonStore] event in
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Cmd+Shift+E → toggle Agent/Files mode
            if chars == "e" && mods.contains(.command) && mods.contains(.shift) {
                guard coordinator.selectedWorktree != nil else { return event }
                detailUIState.contentMode = detailUIState.contentMode == .agent ? .files : .agent
                return nil
            }

            // Cmd+I → toggle Right Panel (Agent mode only)
            if chars == "i" && mods.contains(.command) && !mods.contains(.shift) {
                guard coordinator.selectedWorktree != nil else { return event }
                guard detailUIState.contentMode == .agent else { return event }
                detailUIState.isRightPanelVisible.toggle()
                return nil
            }

            // Cmd+Shift+F → content search (switch to Files mode) — check before Cmd+F
            if chars == "f" && mods.contains(.command) && mods.contains(.shift) {
                guard coordinator.selectedWorktree != nil else { return event }
                quickOpenStore.close()
                detailUIState.contentMode = .files
                searchStore.activate(mode: .content)
                return nil
            }

            // Cmd+F → file search (switch to Files mode)
            if chars == "f" && mods.contains(.command) && !mods.contains(.shift) {
                guard coordinator.selectedWorktree != nil else { return event }
                quickOpenStore.close()
                detailUIState.contentMode = .files
                searchStore.activate(mode: .files)
                return nil
            }

            // Cmd+P → quick open
            if chars == "p" && mods.contains(.command) {
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
