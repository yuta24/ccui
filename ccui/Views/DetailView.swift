import SwiftUI

struct DetailView: View {
    let worktree: Worktree
    let fileTreeStore: FileTreeStore?
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @State private var rightPanelStore = RightPanelStore()
    @State private var codeViewerStore = CodeViewerStore()
    @State private var diffStore = DiffStore()
    @GestureState private var panelDragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let maxPanelWidth = geometry.size.width * RightPanelStore.maxWidthFraction
            let effectivePanelWidth = rightPanelStore.isExpanded
                ? clampedWidth(rightPanelStore.panelWidth + panelDragOffset, max: maxPanelWidth)
                : 0

            HStack(spacing: 0) {
                // Main content
                VStack(spacing: 0) {
                    topBar
                    Rectangle()
                        .fill(Color.borderSubtle)
                        .frame(height: 1)
                    terminalContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Right panel
                if rightPanelStore.isExpanded {
                    resizeHandle(maxPanelWidth: maxPanelWidth)

                    RightPanelView(
                        store: rightPanelStore,
                        fileTreeStore: fileTreeStore,
                        diffStore: diffStore,
                        codeViewerStore: codeViewerStore,
                        repositoryPath: worktree.path
                    )
                    .frame(width: effectivePanelWidth)
                }
            }
        }
        .onAppear {
            terminalSessionStore.ensureSession(for: worktree)
            startWatching()
        }
        .onDisappear {
            diffStore.stopWatching()
        }
        .onChange(of: worktree) { _, newWorktree in
            terminalSessionStore.ensureSession(for: newWorktree)
            codeViewerStore.reset()
            diffStore.reset()
            rightPanelStore.backToFileTree()
            startWatching()
            if rightPanelStore.isExpanded {
                Task { await diffStore.load(repositoryPath: newWorktree.path) }
            }
        }
        .onChange(of: rightPanelStore.isExpanded) { _, isOpen in
            if isOpen, diffStore.needsLoad {
                Task { await diffStore.load(repositoryPath: worktree.path) }
            }
        }
        .onChange(of: fileTreeStore?.selectedNode) { _, newValue in
            guard let node = newValue, !node.isDirectory else { return }
            rightPanelStore.selectFile(node)
            rightPanelStore.expand()
            if diffStore.needsLoad {
                Task { await diffStore.load(repositoryPath: worktree.path) }
            }
        }
    }

    private func startWatching() {
        diffStore.startWatching(repositoryPath: worktree.path) { [rightPanelStore] in
            rightPanelStore.isExpanded
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 0) {
            Spacer()

            // Worktree name
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 9, weight: .medium))
                Text(worktree.displayName)
                    .font(.uiCaption)
            }
            .foregroundStyle(Color.textTertiary)

            Spacer()

            // Panel toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    rightPanelStore.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 10, weight: .medium))
                    Text("Panel")
                        .font(.uiLabel)
                }
                .foregroundStyle(rightPanelStore.isExpanded ? Color.accent : Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(rightPanelStore.isExpanded ? Color.accentSubtle : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
        .frame(height: 36)
        .background(Color.surfaceBase)
    }

    // MARK: - Terminal Content

    private var terminalContent: some View {
        Group {
            if let session = terminalSessionStore.session(for: worktree) {
                TerminalContainerView(session: session, isActive: true)
            } else {
                Color.surfacePrimary
            }
        }
    }

    // MARK: - Resize Handle

    private func resizeHandle(maxPanelWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(width: 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($panelDragOffset) { value, state, _ in
                        state = -value.translation.width
                    }
                    .onEnded { value in
                        let delta = -value.translation.width
                        rightPanelStore.panelWidth = clampedWidth(
                            rightPanelStore.panelWidth + delta,
                            max: maxPanelWidth
                        )
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Helpers

    private func clampedWidth(_ width: CGFloat, max maxWidth: CGFloat) -> CGFloat {
        min(maxWidth, max(RightPanelStore.minWidth, width))
    }
}
