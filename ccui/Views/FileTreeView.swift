import SwiftUI

struct FileTreeView: View {
    let store: FileTreeStore

    @State private var hoveredNode: FileNode.ID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Explorer")
                    .sectionHeader()
                Spacer()
                Button {
                    Task { await store.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Reload file tree")
                .disabled(store.isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            // Content
            if store.isLoading && store.nodes.isEmpty {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.accent)
                Spacer()
            } else if let errorMessage = store.errorMessage, store.nodes.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 20, weight: .ultraLight))
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
                        FileTreeNodeList(nodes: store.nodes, store: store, hoveredNode: $hoveredNode, depth: 0)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(Color.surfaceBase)
        .task {
            if store.nodes.isEmpty && !store.isLoading {
                await store.load()
            }
        }
    }
}

private struct FileTreeNodeList: View {
    let nodes: [FileNode]
    let store: FileTreeStore
    @Binding var hoveredNode: FileNode.ID?
    let depth: Int

    var body: some View {
        ForEach(nodes) { node in
            if node.isDirectory {
                directoryRow(node)
            } else {
                fileRow(node)
            }
        }
    }

    private func directoryRow(_ node: FileNode) -> some View {
        let isExpanded = store.expandedIDs.contains(node.id)

        return VStack(spacing: 0) {
            Button {
                if isExpanded {
                    store.collapse(node)
                } else {
                    store.expand(node)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 12)

                    Image(systemName: isExpanded ? "folder" : "folder.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accent.opacity(0.7))

                    Text(node.name)
                        .font(.uiLabel)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.leading, CGFloat(depth) * 14 + 8)
                .padding(.trailing, 8)
                .padding(.vertical, 3)
                .background(
                    hoveredNode == node.id ? Color.surfaceHover : Color.clear
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                hoveredNode = hovering ? node.id : nil
            }

            if isExpanded {
                if store.loadingIDs.contains(node.id) {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, CGFloat(depth + 1) * 14 + 24)
                    .padding(.vertical, 4)
                } else {
                    FileTreeNodeList(nodes: node.children, store: store, hoveredNode: $hoveredNode, depth: depth + 1)
                }
            }
        }
    }

    private func fileRow(_ node: FileNode) -> some View {
        let isSelected = store.selectedNode?.id == node.id

        return Button {
            store.selectNode(node)
        } label: {
            HStack(spacing: 4) {
                Color.clear
                    .frame(width: 12)

                Image(systemName: fileIcon(for: node.name))
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.accent : Color.textTertiary)

                Text(node.name)
                    .font(.uiLabel)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.leading, CGFloat(depth) * 14 + 8)
            .padding(.trailing, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentSubtle : (hoveredNode == node.id ? Color.surfaceHover : Color.clear))
                    .padding(.horizontal, 4)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredNode = hovering ? node.id : nil
        }
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "jsx", "ts", "tsx": return "chevron.left.forwardslash.chevron.right"
        case "json": return "curlybraces"
        case "md", "txt": return "doc.plaintext"
        case "yml", "yaml", "toml": return "gearshape"
        case "png", "jpg", "jpeg", "gif", "svg", "ico": return "photo"
        case "sh", "zsh", "bash": return "terminal"
        case "css", "scss": return "paintbrush"
        case "html": return "globe"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "rb": return "diamond"
        case "go": return "chevron.left.forwardslash.chevron.right"
        case "rs": return "gearshape.2"
        case "lock": return "lock"
        case "gitignore", "gitmodules", "gitattributes": return "arrow.triangle.branch"
        default: return "doc"
        }
    }
}
