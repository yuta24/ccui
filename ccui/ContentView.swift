import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(ShellSessionStore.self) private var shellSessionStore
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
    @State private var escMonitor: Any?

    var body: some View {
        @Bindable var coordinator = coordinator

        ZStack {
            VStack(spacing: 0) {
                AgentDashboardBar()

                HStack(spacing: 0) {
                    SidebarView()
                        .frame(width: max(180, min(400, sidebarWidth + dragOffset)))
                        .background(Color.surfaceBase)

                    // Sidebar resize handle
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

                    if let worktree = coordinator.selectedWorktree {
                        DetailView(
                            worktree: worktree,
                            fileTreeStore: coordinator.fileTreeStore,
                            fileOverlayStore: fileOverlayStore,
                            codeViewerStore: codeViewerStore,
                            sessionComparisonStore: sessionComparisonStore
                        )
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

            if fileOverlayStore.isVisible, let worktree = coordinator.selectedWorktree {
                FileOverlayView(
                    store: fileOverlayStore,
                    fileTreeStore: coordinator.fileTreeStore,
                    codeViewerStore: codeViewerStore,
                    searchStore: searchStore,
                    repositoryPath: worktree.path
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))

                if quickOpenStore.isVisible {
                    QuickOpenPaletteView(
                        quickOpenStore: quickOpenStore,
                        fileOverlayStore: fileOverlayStore,
                        fileTreeStore: coordinator.fileTreeStore,
                        repositoryPath: worktree.path
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
        }
        .environment(diffStore)
        .animation(.easeInOut(duration: 0.2), value: fileOverlayStore.isVisible)
        .animation(.easeInOut(duration: 0.2), value: sessionComparisonStore.isVisible)
        .animation(.easeInOut(duration: 0.15), value: quickOpenStore.isVisible)
        .onChange(of: fileOverlayStore.isVisible) { _, newValue in
            if !newValue {
                quickOpenStore.close()
                searchStore.deactivate()
            }
        }
        .onChange(of: coordinator.selectedWorktree) { _, newValue in
            fileOverlayStore.close()
            sessionComparisonStore.close()
            quickOpenStore.close()
            searchStore.deactivate()
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

    private func installKeyMonitor() {
        if let existing = escMonitor {
            NSEvent.removeMonitor(existing)
            escMonitor = nil
        }

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [fileOverlayStore, quickOpenStore, searchStore, coordinator, sessionComparisonStore] event in
            // Cmd+F → file search
            if event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) && event.keyCode == 3 {
                guard coordinator.selectedWorktree != nil else { return event }
                quickOpenStore.close()
                if !fileOverlayStore.isVisible {
                    fileOverlayStore.open()
                }
                searchStore.activate(mode: .files)
                return nil
            }

            // Cmd+Shift+E → toggle file explorer
            if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && event.keyCode == 14 {
                guard coordinator.selectedWorktree != nil else { return event }
                quickOpenStore.close()
                searchStore.deactivate()
                fileOverlayStore.toggle()
                return nil
            }

            // Cmd+Shift+F → content search
            if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && event.keyCode == 3 {
                guard coordinator.selectedWorktree != nil else { return event }
                quickOpenStore.close()
                if !fileOverlayStore.isVisible {
                    fileOverlayStore.open()
                }
                searchStore.activate(mode: .content)
                return nil
            }

            // Esc to close comparison overlay
            if event.keyCode == 53, sessionComparisonStore.isVisible {
                sessionComparisonStore.close()
                return nil
            }

            guard fileOverlayStore.isVisible else { return event }

            // Esc
            if event.keyCode == 53 {
                if quickOpenStore.isVisible {
                    quickOpenStore.close()
                } else if searchStore.isActive {
                    searchStore.deactivate()
                } else {
                    fileOverlayStore.close()
                }
                return nil
            }

            // Cmd+P
            if event.modifierFlags.contains(.command) && event.keyCode == 35 {
                if !quickOpenStore.isVisible {
                    searchStore.deactivate()
                    quickOpenStore.open()
                }
                return nil
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
