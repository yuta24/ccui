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
    let repository: Repository
    let fileTreeStore: FileTreeStore?
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @State private var selectedTab: DetailTab = .terminal
    @State private var codeViewerStore = CodeViewerStore()

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

            // Content
            ZStack {
                TerminalContainerView(
                    session: terminalSessionStore.session(for: repository),
                    isActive: selectedTab == .terminal
                )
                .opacity(selectedTab == .terminal ? 1 : 0)
                .allowsHitTesting(selectedTab == .terminal)

                CodeViewerView(store: codeViewerStore)
                    .opacity(selectedTab == .code ? 1 : 0)
                    .allowsHitTesting(selectedTab == .code)
                if selectedTab == .diff {
                    DiffViewerPlaceholderView()
                }
            }
        }
        .navigationTitle(repository.name)
        .onChange(of: fileTreeStore?.selectedNode) { _, newValue in
            guard let node = newValue, !node.isDirectory else { return }
            selectedTab = .code
            Task { await codeViewerStore.load(path: node.path) }
        }
        .onChange(of: repository) { _, _ in
            codeViewerStore.reset()
        }
    }
}
