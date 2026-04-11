import SwiftUI

struct FileViewerView: View {
    let node: FileNode
    let codeViewerStore: CodeViewerStore
    let repositoryPath: String
    @Environment(DiffStore.self) private var diffStore

    var body: some View {
        VStack(spacing: 0) {
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
            entry.status != .untracked
                && (entry.newPath == relativePath || entry.oldPath == relativePath)
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

    private func relativePath(for fullPath: String) -> String {
        if fullPath.hasPrefix(repositoryPath + "/") {
            return String(fullPath.dropFirst(repositoryPath.count + 1))
        }
        return fullPath
    }
}
