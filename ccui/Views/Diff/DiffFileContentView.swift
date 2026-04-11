import SwiftUI

struct DiffFileContentView: View {
    let entry: DiffFileEntry

    var body: some View {
        if entry.status == .untracked {
            placeholderView(icon: "doc.badge.plus", message: "Untracked file")
        } else if entry.isBinary {
            placeholderView(icon: "doc.questionmark", message: "Binary file changed")
        } else if entry.hunks.isEmpty {
            placeholderView(icon: "checkmark.circle", message: "File mode or metadata changed")
        } else {
            diffLines
        }
    }

    private func placeholderView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)
            Text(message)
                .font(.uiLabel)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var diffLines: some View {
        let maxOldLine = entry.hunks.flatMap(\.lines).compactMap(\.oldLineNumber).max() ?? 0
        let maxNewLine = entry.hunks.flatMap(\.lines).compactMap(\.newLineNumber).max() ?? 0
        let gutterWidth = lineNumberWidth(maxLine: max(maxOldLine, maxNewLine))
        let items = displayItems

        return GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(items) { item in
                        switch item {
                        case .header(_, let text):
                            hunkHeaderRow(text)
                        case .line(let line):
                            diffLineRow(line: line, gutterWidth: gutterWidth)
                        }
                    }
                }
                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .topLeading)
            }
        }
        .background(Color.surfacePrimary)
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
