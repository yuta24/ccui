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
    @State private var selectedTab: DetailTab = .terminal

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
            switch selectedTab {
            case .terminal:
                TerminalPlaceholderView(repository: repository)
            case .code:
                CodeViewerPlaceholderView()
            case .diff:
                DiffViewerPlaceholderView()
            }
        }
        .navigationTitle(repository.name)
    }
}
