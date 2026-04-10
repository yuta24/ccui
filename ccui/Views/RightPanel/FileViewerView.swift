import SwiftUI

struct FileViewerView: View {
    let node: FileNode
    let diffStore: DiffStore
    let codeViewerStore: CodeViewerStore
    let repositoryPath: String

    var body: some View {
        VStack(spacing: 0) {
            if diffEntry != nil {
                diffModeToolbar
                Rectangle()
                    .fill(Color.borderSubtle)
                    .frame(height: 1)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: node.id) {
            codeViewerStore.reset()
            if !hasDiff {
                await codeViewerStore.load(path: node.path)
            }
        }
        .onChange(of: hasDiff) { oldValue, newValue in
            if oldValue && !newValue {
                Task { await codeViewerStore.load(path: node.path) }
            }
        }
    }

    private var hasDiff: Bool {
        diffEntry != nil
    }

    private var diffEntry: DiffFileEntry? {
        guard case .loaded(let entries) = diffStore.state else { return nil }
        let relativePath = relativePath(for: node.path)
        return entries.first { entry in
            entry.newPath == relativePath || entry.oldPath == relativePath
        }
    }

    @ViewBuilder
    private var content: some View {
        if let entry = diffEntry {
            DiffFileContentView(entry: entry)
        } else {
            CodeViewerView(store: codeViewerStore)
        }
    }

    private var diffModeToolbar: some View {
        HStack(spacing: 8) {
            DiffModeToggle(currentMode: diffStore.mode) { mode in
                Task { await diffStore.load(repositoryPath: repositoryPath, mode: mode) }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.surfaceBase)
    }

    private func relativePath(for fullPath: String) -> String {
        if fullPath.hasPrefix(repositoryPath + "/") {
            return String(fullPath.dropFirst(repositoryPath.count + 1))
        }
        return fullPath
    }
}
