import SwiftUI

enum DetailTab: String, CaseIterable {
    case terminal = "Terminal"
    case code = "Code"
    case diff = "Diff"

    var icon: String {
        switch self {
        case .terminal: "terminal.fill"
        case .code: "doc.text"
        case .diff: "arrow.left.arrow.right"
        }
    }
}

struct DetailView: View {
    let worktree: Worktree
    let fileTreeStore: FileTreeStore?
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @State private var selectedTab: DetailTab = .terminal
    @State private var codeViewerStore = CodeViewerStore()
    @State private var diffStore = DiffStore()

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with tabs and terminal sub-tabs
            topBar

            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            // Content
            ZStack {
                terminalContent
                    .opacity(selectedTab == .terminal ? 1 : 0)
                    .allowsHitTesting(selectedTab == .terminal)

                codeContent
                    .opacity(selectedTab == .code ? 1 : 0)
                    .allowsHitTesting(selectedTab == .code)

                DiffViewerView(store: diffStore, repositoryPath: worktree.path)
                    .opacity(selectedTab == .diff ? 1 : 0)
                    .allowsHitTesting(selectedTab == .diff)
            }
        }
        .onAppear {
            terminalSessionStore.ensureSession(for: worktree)
        }
        .onChange(of: worktree) { _, newWorktree in
            terminalSessionStore.ensureSession(for: newWorktree)
            codeViewerStore.reset()
            diffStore.reset()
            if selectedTab == .diff {
                Task { await diffStore.load(repositoryPath: newWorktree.path) }
            }
        }
        .onChange(of: fileTreeStore?.selectedNode) { _, newValue in
            guard let node = newValue, !node.isDirectory else { return }
            selectedTab = .code
            Task { await codeViewerStore.load(path: node.path) }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .diff, case .idle = diffStore.state {
                Task { await diffStore.load(repositoryPath: worktree.path) }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 0) {
            // Main tabs
            HStack(spacing: 2) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(.leading, 12)

            // Separator
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(width: 1, height: 16)
                .padding(.horizontal, 8)

            // Terminal sub-tabs (only shown when terminal is selected)
            if selectedTab == .terminal {
                terminalTabs
            }

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

    private func tabButton(_ tab: DetailTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: .medium))
                Text(tab.rawValue)
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

    // MARK: - Terminal Tabs

    private var terminalTabs: some View {
        let sessionList = terminalSessionStore.sessions(for: worktree)
        let selectedIndex = terminalSessionStore.selectedIndex(for: worktree)

        return HStack(spacing: 2) {
            ForEach(Array(sessionList.enumerated()), id: \.element.id) { index, session in
                terminalTabButton(
                    index: index,
                    label: session.label,
                    isSelected: index == selectedIndex,
                    canClose: sessionList.count > 1
                )
            }

            Button {
                terminalSessionStore.addSession(for: worktree)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("New terminal")
        }
    }

    private func terminalTabButton(index: Int, label: String, isSelected: Bool, canClose: Bool) -> some View {
        HStack(spacing: 3) {
            Button {
                terminalSessionStore.selectSession(at: index, for: worktree)
            } label: {
                Text(label)
                    .font(.uiCaptionMono)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.plain)

            if canClose {
                Button {
                    terminalSessionStore.removeSession(at: index, for: worktree)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.surfaceElevated : Color.clear)
        )
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

    // MARK: - Terminal Content

    private var terminalContent: some View {
        let sessionList = terminalSessionStore.sessions(for: worktree)
        let selectedIndex = terminalSessionStore.selectedIndex(for: worktree)

        return ZStack {
            ForEach(Array(sessionList.enumerated()), id: \.element.id) { index, session in
                TerminalContainerView(
                    session: session,
                    isActive: selectedTab == .terminal && index == selectedIndex
                )
                .opacity(index == selectedIndex ? 1 : 0)
                .allowsHitTesting(index == selectedIndex)
            }
        }
    }
}
