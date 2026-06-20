import SwiftUI

struct DiffFileRowView: View {
    let entry: DiffFileEntry
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    private var displayPath: String {
        switch entry.status {
        case .deleted:
            entry.oldPath
        case .renamed:
            "\(entry.oldPath) → \(entry.newPath)"
        case .added, .modified, .untracked:
            entry.newPath
        }
    }

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 8) {
                DiffStatusBadge(status: entry.status)

                Text(displayPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.monoCaption)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                if !entry.isBinary && !entry.hunks.isEmpty {
                    statsView
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: PanelMetrics.buttonCornerRadius)
                    .fill(isSelected ? Color.surfaceElevated : (isHovered ? Color.surfaceHover : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PanelMetrics.buttonCornerRadius)
                    .strokeBorder(isSelected ? Color.borderDefault : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var statsView: some View {
        HStack(spacing: 4) {
            if entry.additions > 0 {
                Text("+\(entry.additions)")
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.diffAddition)
            }
            if entry.deletions > 0 {
                Text("-\(entry.deletions)")
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.diffDeletion)
            }
        }
    }
}
