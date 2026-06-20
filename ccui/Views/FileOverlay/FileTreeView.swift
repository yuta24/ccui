import SwiftUI

struct FileTreeView: View {
    let store: FileTreeStore
    var changedFiles: [String: DiffFileEntry.Status] = [:]

    @State private var hoveredNode: FileNode.ID?

    var body: some View {
        VStack(spacing: 0) {
            if store.isLoading && store.nodes.isEmpty {
                Spacer()
                PulsingDotsView()
                Spacer()
            } else if let errorMessage = store.errorMessage, store.nodes.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.emptyStateIconSmall)
                        .foregroundStyle(Color.textTertiary)
                    Text(errorMessage)
                        .font(.uiCaption)
                        .foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        FileTreeNodeList(nodes: store.nodes, store: store, hoveredNode: $hoveredNode, changedFiles: changedFiles, depth: 0)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(Color.surfacePrimary)
        .task {
            if store.nodes.isEmpty && !store.isLoading {
                await store.load()
            }
        }
    }
}
