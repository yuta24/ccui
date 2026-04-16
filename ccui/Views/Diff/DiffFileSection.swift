import SwiftUI

struct DiffFileSection: View {
    let entry: DiffFileEntry

    @State private var isExpanded = true

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
        VStack(spacing: 0) {
            fileHeader
            if isExpanded {
                fileContent
            }
        }
    }

    // MARK: - Header

    private var fileHeader: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 10)

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
            .background(Color.surfaceElevated)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderSubtle).frame(height: 1)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var fileContent: some View {
        if entry.status == .untracked {
            inlinePlaceholder(icon: "doc.badge.plus", message: "Untracked file")
        } else if entry.isBinary {
            inlinePlaceholder(icon: "doc.questionmark", message: "Binary file changed")
        } else if entry.hunks.isEmpty {
            inlinePlaceholder(icon: "checkmark.circle", message: "File mode or metadata changed")
        } else {
            inlineDiffLines
        }
    }

    private func inlinePlaceholder(icon: String, message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textTertiary)
            Text(message)
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.surfacePrimary)
    }

    private var inlineDiffLines: some View {
        let allLines = entry.hunks.flatMap(\.lines)
        let maxOldLine = allLines.compactMap(\.oldLineNumber).max() ?? 0
        let maxNewLine = allLines.compactMap(\.newLineNumber).max() ?? 0
        let gutterWidth = lineNumberWidth(maxLine: max(maxOldLine, maxNewLine))
        let items = displayItems

        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                switch item {
                case .header(_, let text):
                    hunkHeaderRow(text)
                case .line(let line):
                    diffLineRow(line: line, gutterWidth: gutterWidth)
                }
            }
        }
        .background(Color.surfacePrimary)
    }

    private enum DisplayItem: Identifiable {
        case header(id: Int, text: String)
        case line(DiffLine)

        var id: Int {
            switch self {
            case .header(let id, _): id
            case .line(let line): line.id
            }
        }
    }

    private var displayItems: [DisplayItem] {
        var items: [DisplayItem] = []
        for hunk in entry.hunks {
            items.append(.header(id: -hunk.id - 1, text: hunk.header))
            for line in hunk.lines {
                items.append(.line(line))
            }
        }
        return items
    }

    private func hunkHeaderRow(_ header: String) -> some View {
        HStack(spacing: 0) {
            Text(header)
                .font(.monoCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.surfaceElevated)
    }

    private func diffLineRow(line: DiffLine, gutterWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(line.oldLineNumber.map(String.init) ?? "")
                .font(.monoCaption)
                .foregroundStyle(Color.gutterText)
                .frame(width: gutterWidth, alignment: .trailing)

            Text(line.newLineNumber.map(String.init) ?? "")
                .font(.monoCaption)
                .foregroundStyle(Color.gutterText)
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 4)

            Rectangle()
                .fill(Color.borderSubtle)
                .frame(width: 1)
                .padding(.trailing, 8)

            Text(lineSign(line.kind))
                .font(.monoCaption)
                .foregroundStyle(lineColor(line.kind))
                .frame(width: 12)

            Text(line.content.isEmpty ? " " : line.content)
                .font(.monoCaption)
                .foregroundStyle(contentColor(line.kind))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(lineBackground(line.kind))
    }

    // MARK: - Helpers

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

    private func lineSign(_ kind: DiffLineKind) -> String {
        switch kind {
        case .addition: "+"
        case .deletion: "-"
        case .context: " "
        }
    }

    private func lineColor(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .addition: .diffAddition
        case .deletion: .diffDeletion
        case .context: .textTertiary
        }
    }

    private func contentColor(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .addition: .diffAddition.opacity(0.9)
        case .deletion: .diffDeletion.opacity(0.9)
        case .context: .textSecondary
        }
    }

    private func lineBackground(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .addition: .diffAdditionBg
        case .deletion: .diffDeletionBg
        case .context: .clear
        }
    }

    private func lineNumberWidth(maxLine: Int) -> CGFloat {
        let digits = max(String(maxLine).count, 3)
        return CGFloat(digits) * 7 + 4
    }
}
