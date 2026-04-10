import SwiftUI

struct RightPanelView: View {
    let store: RightPanelStore
    let fileTreeStore: FileTreeStore?
    let diffStore: DiffStore
    let codeViewerStore: CodeViewerStore
    let repositoryPath: String

    var body: some View {
        VStack(spacing: 0) {
            panelHeader

            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            panelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .background(Color.surfaceBase)
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: 8) {
            switch store.content {
            case .fileTree:
                Text("Explorer")
                    .sectionHeader()

                if let fileTreeStore {
                    Button {
                        Task { await fileTreeStore.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Reload file tree")
                    .disabled(fileTreeStore.isLoading)
                }

            case .viewer(let node):
                Button {
                    store.backToFileTree()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Back to file tree")

                Text(node.name)
                    .font(.uiLabel)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.collapse()
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
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.surfaceBase)
    }

    // MARK: - Content

    @ViewBuilder
    private var panelContent: some View {
        switch store.content {
        case .fileTree:
            if let fileTreeStore {
                FileTreeView(store: fileTreeStore, changedFiles: changedFiles)
            } else {
                Color.surfaceBase
            }

        case .viewer(let node):
            FileViewerView(
                node: node,
                diffStore: diffStore,
                codeViewerStore: codeViewerStore,
                repositoryPath: repositoryPath
            )
        }
    }

    private var changedFiles: [String: DiffFileEntry.Status] {
        guard case .loaded(let entries) = diffStore.state else { return [:] }
        var result: [String: DiffFileEntry.Status] = [:]
        for entry in entries {
            let path = entry.status == .deleted ? entry.oldPath : entry.newPath
            let fullPath = (repositoryPath as NSString).appendingPathComponent(path)
            result[fullPath] = entry.status
            if entry.status == .renamed {
                let oldFullPath = (repositoryPath as NSString).appendingPathComponent(entry.oldPath)
                result[oldFullPath] = .deleted
            }
        }
        return result
    }
}
