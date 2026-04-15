import SwiftUI

struct DetailView: View {
    let worktree: Worktree
    let fileTreeStore: FileTreeStore?
    let fileOverlayStore: FileOverlayStore
    let codeViewerStore: CodeViewerStore
    let searchStore: SearchStore
    let sessionComparisonStore: SessionComparisonStore
    @Environment(DetailUIState.self) private var uiState
    @Environment(DiffStore.self) private var diffStore
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(AppCoordinator.self) private var coordinator
    @State private var isBottomPanelExpanded = false
    @State private var bottomPanelHeight: CGFloat = 220
    @GestureState private var bottomPanelDragOffset: CGFloat = 0
    @State private var bottomPanelCursorPushed = false
    @State private var bottomPanelHandleHovered = false

    var body: some View {
        VStack(spacing: 0) {
            mainContent
            bottomPanel
        }
        .onAppear {
            diffStore.reset()
            codeViewerStore.reset()
            startWatching()
        }
        .onDisappear {
            diffStore.stopWatching()
        }
        .onChange(of: worktree) { _, _ in
            isBottomPanelExpanded = false
            bottomPanelHeight = 220
            codeViewerStore.reset()
            diffStore.reset()
            fileOverlayStore.deselectFile()
            startWatching()
        }
        .onChange(of: terminalSessionStore.session(for: worktree) != nil) { _, hasSession in
            if !hasSession {
                uiState.isRightPanelVisible = false
            }
        }
        .onChange(of: uiState.contentMode) { _, newMode in
            if newMode == .files, diffStore.needsLoad {
                Task { await diffStore.load(repositoryPath: worktree.path) }
            }
        }
        .onChange(of: fileTreeStore?.selectedNode) { _, newValue in
            guard let node = newValue, !node.isDirectory else { return }
            fileOverlayStore.selectFile(node)
            uiState.contentMode = .files
            if diffStore.needsLoad {
                Task { await diffStore.load(repositoryPath: worktree.path) }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        HStack(spacing: 0) {
            switch uiState.contentMode {
            case .agent:
                AgentContentView(worktree: worktree)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if uiState.isRightPanelVisible {
                    RightPanelView(
                        worktreePath: worktree.path,
                        repositoryPath: worktree.path,
                        statsRepositoryPath: repositoryPath,
                        sessionEvaluationStore: uiState.sessionEvaluationStore,
                        selectedTab: Binding(
                            get: { uiState.rightPanelTab },
                            set: { uiState.rightPanelTab = $0 }
                        )
                    )
                }

            case .files:
                FilesContentView(
                    fileTreeStore: fileTreeStore,
                    fileOverlayStore: fileOverlayStore,
                    codeViewerStore: codeViewerStore,
                    searchStore: searchStore,
                    repositoryPath: worktree.path
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            if isBottomPanelExpanded {
                bottomPanelResizeHandle
            }

            BottomTerminalPanelView(worktreePath: worktree.path, isExpanded: $isBottomPanelExpanded)
                .frame(height: isBottomPanelExpanded ? max(120, min(600, bottomPanelHeight + bottomPanelDragOffset)) : nil)
        }
    }

    private var bottomPanelResizeHandle: some View {
        Rectangle()
            .fill(bottomPanelHandleHovered ? Color.borderStrong : Color.borderSubtle)
            .frame(height: bottomPanelHandleHovered ? 3 : 1)
            .animation(.easeInOut(duration: 0.15), value: bottomPanelHandleHovered)
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
                bottomPanelHandleHovered = hovering
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

    // MARK: - Diff Watching

    private func startWatching() {
        let uiState = uiState
        diffStore.startWatching(repositoryPath: worktree.path) {
            uiState.contentMode == .files || uiState.isRightPanelVisible
        }
    }

    // MARK: - Computed

    private var repositoryPath: String {
        coordinator.worktreeStores[worktree.repositoryID]?.repositoryPath ?? worktree.path
    }

}
