import SwiftUI

struct FileTreeView: View {
    let store: FileTreeStore

    var body: some View {
        VStack(spacing: 0) {
            // Header with reload button
            HStack {
                Text("Files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    Task { await store.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Reload file tree")
                .disabled(store.isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // Content
            if store.isLoading && store.nodes.isEmpty {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            } else if let errorMessage = store.errorMessage, store.nodes.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                List {
                    FileTreeNodeList(nodes: store.nodes, store: store)
                }
                .listStyle(.sidebar)
            }
        }
        .task {
            await store.load()
        }
    }
}

private struct FileTreeNodeList: View {
    let nodes: [FileNode]
    let store: FileTreeStore

    var body: some View {
        ForEach(nodes) { node in
            if node.isDirectory {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { store.expandedIDs.contains(node.id) },
                        set: { isExpanded in
                            if isExpanded {
                                store.expand(node)
                            } else {
                                store.collapse(node)
                            }
                        }
                    )
                ) {
                    if store.loadingIDs.contains(node.id) {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)
                    } else {
                        FileTreeNodeList(nodes: node.children, store: store)
                    }
                } label: {
                    Label {
                        Text(node.name)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                Button {
                    store.selectNode(node)
                } label: {
                    Label {
                        Text(node.name)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "doc")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    store.selectedNode?.id == node.id
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )
            }
        }
    }
}
