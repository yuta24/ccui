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
                        .font(.iconTiny)
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 12)

                    Image(systemName: isExpanded ? "folder" : "folder.fill")
                        .font(.iconMedium)
                        .foregroundStyle(Color.accent.opacity(Opacity.mutedAccent))

                    Text(node.name)
                        .font(.uiLabel)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)

                    Spacer()
                }
                .opacity(isIgnored ? Opacity.dimmed : 1.0)
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
                    .font(.iconMedium)
                    .foregroundStyle(iconColor(isSelected: isSelected, changeStatus: changeStatus))

                Text(node.name)
                    .font(.uiLabel)
                    .foregroundStyle(labelColor(isSelected: isSelected, changeStatus: changeStatus))
                    .lineLimit(1)

                Spacer()

                if let status = changeStatus {
                    DiffStatusBadge(status: status)
                }
            }
            .opacity(isIgnored ? Opacity.dimmed : 1.0)
            .padding(.leading, CGFloat(depth) * 14 + 8)
            .padding(.trailing, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: PanelMetrics.buttonCornerRadius)
                    .fill(isSelected ? Color.accentSubtle : (hoveredNode == node.id ? Color.surfaceHover : Color.clear))
                    .padding(.horizontal, 4)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredNode = hovering ? node.id : nil
        }
    }

    private func iconColor(isSelected: Bool, changeStatus: DiffFileEntry.Status?) -> Color {
        if isSelected { return Color.accent }
        if let changeStatus { return FileTreeHelpers.statusColor(changeStatus) }
        return Color.textTertiary
    }

    private func labelColor(isSelected: Bool, changeStatus: DiffFileEntry.Status?) -> Color {
        if isSelected { return Color.textPrimary }
        if let changeStatus { return FileTreeHelpers.statusColor(changeStatus) }
        return Color.textSecondary
    }
}
