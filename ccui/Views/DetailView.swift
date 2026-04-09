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
            // Tab bar
            HStack(spacing: 0) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Terminal sub-tab bar
            if selectedTab == .terminal {
                terminalTabBar
                Divider()
            }

            // Content
            ZStack {
                terminalContent
                    .opacity(selectedTab == .terminal ? 1 : 0)
                    .allowsHitTesting(selectedTab == .terminal)

                CodeViewerView(store: codeViewerStore)
                    .opacity(selectedTab == .code ? 1 : 0)
                    .allowsHitTesting(selectedTab == .code)
                DiffViewerView(store: diffStore, repositoryPath: worktree.path)
                    .opacity(selectedTab == .diff ? 1 : 0)
                    .allowsHitTesting(selectedTab == .diff)
            }
        }
        .navigationTitle(worktree.displayName)
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

    // MARK: - Terminal sub-tab bar

    private var terminalTabBar: some View {
        let sessionList = terminalSessionStore.sessions(for: worktree)
        let selectedIndex = terminalSessionStore.selectedIndex(for: worktree)

        return HStack(spacing: 0) {
            ForEach(Array(sessionList.enumerated()), id: \.element.id) { index, session in
                terminalTab(index: index, label: session.label, isSelected: index == selectedIndex, canClose: sessionList.count > 1)
            }

            Button {
                terminalSessionStore.addSession(for: worktree)
            } label: {
                Image(systemName: "plus")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help("New terminal")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func terminalTab(index: Int, label: String, isSelected: Bool, canClose: Bool) -> some View {
        HStack(spacing: 4) {
            Button {
                terminalSessionStore.selectSession(at: index, for: worktree)
            } label: {
                Text(label)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if canClose {
                Button {
                    terminalSessionStore.removeSession(at: index, for: worktree)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
    }

    // MARK: - Terminal content

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
