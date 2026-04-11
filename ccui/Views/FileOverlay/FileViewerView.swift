import SwiftUI

struct FileViewerView: View {
    let node: FileNode
    let codeViewerStore: CodeViewerStore
    let repositoryPath: String
    @Environment(DiffStore.self) private var diffStore

    private enum ViewMode: String, CaseIterable {
        case code = "Code"
        case diff = "Diff"
    }

    @State private var viewMode: ViewMode = .code

    var body: some View {
        VStack(spacing: 0) {
            if hasDiff {
                viewModeBar
                Rectangle()
                    .fill(Color.borderSubtle)
                    .frame(height: 1)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .task(id: node.id) {
            viewMode = .code
            codeViewerStore.reset()
            await codeViewerStore.load(path: node.path)
        }
    }

    private var hasDiff: Bool {
        diffEntry != nil
    }

    private var diffEntry: DiffFileEntry? {
        guard case .loaded(let entries) = diffStore.state else { return nil }
        let relativePath = relativePath(for: node.path)
        return entries.first { entry in
            entry.status != .untracked
                && (entry.newPath == relativePath || entry.oldPath == relativePath)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewMode == .diff, let entry = diffEntry {
            DiffFileContentView(entry: entry)
        } else {
            CodeViewerView(store: codeViewerStore)
        }
    }

    private var viewModeBar: some View {
        HStack {
            Spacer()
            HStack(spacing: 0) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    let isSelected = viewMode == mode
                    Button {
                        viewMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.uiCaption)
                            .foregroundStyle(isSelected ? Color.surfaceBase : Color.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(isSelected ? Color.accent : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.borderSubtle, lineWidth: 1)
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.surfaceBase)
    }

    private func relativePath(for fullPath: String) -> String {
        if fullPath.hasPrefix(repositoryPath + "/") {
            return String(fullPath.dropFirst(repositoryPath.count + 1))
        }
        return fullPath
    }
}
