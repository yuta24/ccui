import SwiftUI

struct FileTreeNodeList: View {
    let nodes: [FileNode]
    let store: FileTreeStore
    @Binding var hoveredNode: FileNode.ID?
    let changedFiles: [String: DiffFileEntry.Status]
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

    // MARK: - Directory Row

    private func directoryRow(_ node: FileNode) -> some View {
        let isExpanded = store.expandedIDs.contains(node.id)
        let isIgnored = node.gitIgnoreStatus == .ignored

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
                .opacity(isIgnored ? 0.4 : 1.0)
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
                        PulsingDotsView(dotSize: 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, CGFloat(depth + 1) * 14 + 24)
                    .padding(.vertical, 4)
                } else {
                    FileTreeNodeList(nodes: node.children, store: store, hoveredNode: $hoveredNode, changedFiles: changedFiles, depth: depth + 1)
                }
            }
        }
    }

    // MARK: - File Row

    private func fileRow(_ node: FileNode) -> some View {
        let isSelected = store.selectedNode?.id == node.id
        let changeStatus = changedFiles[node.path]
        let isIgnored = node.gitIgnoreStatus == .ignored

        return Button {
            store.selectNode(node)
        } label: {
            HStack(spacing: 4) {
                Color.clear
                    .frame(width: 12)

                Image(systemName: FileTreeHelpers.fileIcon(for: node.name))
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.accent : (changeStatus != nil ? FileTreeHelpers.statusColor(changeStatus!) : Color.textTertiary))

                Text(node.name)
                    .font(.uiLabel)
                    .foregroundStyle(isSelected ? Color.textPrimary : (changeStatus != nil ? FileTreeHelpers.statusColor(changeStatus!) : Color.textSecondary))
                    .lineLimit(1)

                Spacer()

                if let status = changeStatus {
                    Text(FileTreeHelpers.statusLetter(status))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(FileTreeHelpers.statusColor(status))
                        .frame(width: 16, height: 16)
                        .background(FileTreeHelpers.statusColor(status).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .opacity(isIgnored ? 0.4 : 1.0)
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
}
