import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(AppCoordinator.self) private var coordinator
    @State private var sidebarWidth: CGFloat = 240
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        @Bindable var coordinator = coordinator

        VStack(spacing: 0) {
            AgentDashboardBar()

            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: max(180, min(400, sidebarWidth + dragOffset)))
                    .background(Color.surfaceBase)

                // Sidebar resize handle
                Rectangle()
                    .fill(Color.borderSubtle)
                    .frame(width: 1)
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
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }

                if let worktree = coordinator.selectedWorktree {
                    DetailView(worktree: worktree, fileTreeStore: coordinator.fileTreeStore)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.surfacePrimary)
                } else {
                    emptyState
                }
            }
        }
        .background(Color.surfaceBase)
        .onChange(of: coordinator.selectedWorktree) { _, newValue in
            if let wt = newValue {
                claudeEventStore.acknowledge(for: wt.path)
            }
        }
        .onChange(of: claudeEventStore.eventHistory) { _, _ in
            if let wt = coordinator.selectedWorktree, claudeEventStore.hasUnacknowledged(for: wt.path) {
                claudeEventStore.acknowledge(for: wt.path)
            }
        }
        .onChange(of: store.repositories) { _, newValue in
            coordinator.syncWorktreeStores(
                with: newValue,
                terminalSessionStore: terminalSessionStore,
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
                coordinator.forceDeleteWorktree(terminalSessionStore: terminalSessionStore)
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
