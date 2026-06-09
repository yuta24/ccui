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
                statusBadge

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
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.surfaceElevated : (isHovered ? Color.surfaceHover : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isSelected ? Color.borderDefault : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var statusBadge: some View {
        Text(statusLetter)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(statusColor)
            .frame(width: 16, height: 16)
            .background(statusColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var statusLetter: String {
        switch entry.status {
        case .added: "A"
        case .modified: "M"
        case .deleted: "D"
        case .renamed: "R"
        case .untracked: "U"
        }
    }

    private var statusColor: Color {
        switch entry.status {
        case .added: .diffAddition
        case .modified: .accent
        case .deleted: .diffDeletion
        case .renamed: .statusRenamed
        case .untracked: .diffAddition
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
