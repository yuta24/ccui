import SwiftUI

struct DetailView: View {
    let worktree: Worktree
    let fileTreeStore: FileTreeStore?
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @State private var bottomPanelStore = BottomPanelStore()
    @State private var codeViewerStore = CodeViewerStore()
    @State private var diffStore = DiffStore()
    @GestureState private var panelDragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let maxPanelHeight = geometry.size.height * BottomPanelStore.maxHeightFraction
            let effectivePanelHeight = bottomPanelStore.isExpanded
                ? clampedHeight(bottomPanelStore.panelHeight + panelDragOffset, max: maxPanelHeight)
                : 0

            VStack(spacing: 0) {
                // Top bar
                topBar

                Rectangle()
                    .fill(Color.borderSubtle)
                    .frame(height: 1)

                // Terminal (fills remaining space)
                terminalContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Drag handle + bottom panel
                if bottomPanelStore.isExpanded {
                    dragHandle(maxPanelHeight: maxPanelHeight)

                    bottomPanel
                        .frame(height: effectivePanelHeight)
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
            startWatching()
        }
        .onChange(of: bottomPanelStore.isExpanded) { _, isOpen in
            if isOpen, diffStore.needsLoad {
                Task { await diffStore.load(repositoryPath: worktree.path) }
            }
        }
        .onChange(of: fileTreeStore?.selectedNode) { _, newValue in
            guard let node = newValue, !node.isDirectory else { return }
            bottomPanelStore.selectedTab = .code
            bottomPanelStore.expand()
            Task { await codeViewerStore.load(path: node.path) }
        }
    }

    private func startWatching() {
        diffStore.startWatching(repositoryPath: worktree.path) { [bottomPanelStore] in
            bottomPanelStore.isExpanded && bottomPanelStore.selectedTab == .diff
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 0) {
            // Panel toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    bottomPanelStore.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: bottomPanelStore.isExpanded ? "rectangle.bottomhalf.filled" : "rectangle.bottomhalf.inset.filled")
                        .font(.system(size: 10, weight: .medium))
                    Text("Panel")
                        .font(.uiLabel)
                }
                .foregroundStyle(bottomPanelStore.isExpanded ? Color.accent : Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(bottomPanelStore.isExpanded ? Color.accentSubtle : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)

            Spacer()

            // Worktree name
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 9, weight: .medium))
                Text(worktree.displayName)
                    .font(.uiCaption)
            }
            .foregroundStyle(Color.textTertiary)
            .padding(.trailing, 14)
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

    // MARK: - Drag Handle

    private func dragHandle(maxPanelHeight: CGFloat) -> some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(height: 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($panelDragOffset) { value, state, _ in
                        state = -value.translation.height
                    }
                    .onEnded { value in
                        let delta = -value.translation.height
                        bottomPanelStore.panelHeight = clampedHeight(
                            bottomPanelStore.panelHeight + delta,
                            max: maxPanelHeight
                        )
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            panelTabBar

            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            Group {
                switch bottomPanelStore.selectedTab {
                case .diff:
                    DiffViewerView(store: diffStore, repositoryPath: worktree.path)
                case .code:
                    codeContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.surfacePrimary)
        .clipped()
    }

    private var panelTabBar: some View {
        HStack(spacing: 2) {
            panelTabButton(.diff, icon: "arrow.left.arrow.right", label: "Diff")
            panelTabButton(.code, icon: "doc.text", label: "Code")

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    bottomPanelStore.collapse()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Close panel")
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(Color.surfaceBase)
    }

    private func panelTabButton(_ tab: BottomPanelStore.PanelTab, icon: String, label: String) -> some View {
        let isSelected = bottomPanelStore.selectedTab == tab

        return Button {
            bottomPanelStore.selectedTab = tab
            if tab == .diff, diffStore.needsLoad {
                Task { await diffStore.load(repositoryPath: worktree.path) }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.uiLabel)
            }
            .foregroundStyle(isSelected ? Color.accent : Color.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentSubtle : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Code Content

    private var codeContent: some View {
        HSplitView {
            if let fileTreeStore {
                FileTreeView(store: fileTreeStore)
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 350)
            }
            CodeViewerView(store: codeViewerStore)
        }
    }

    // MARK: - Helpers

    private func clampedHeight(_ height: CGFloat, max maxHeight: CGFloat) -> CGFloat {
        min(maxHeight, max(BottomPanelStore.minHeight, height))
    }
}
