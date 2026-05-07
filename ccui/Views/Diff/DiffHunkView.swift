import SwiftUI

struct DiffHunkView: View, Equatable {
    let hunk: DiffHunk
    let gutterWidth: CGFloat
    let contentWidth: CGFloat

    static func == (lhs: DiffHunkView, rhs: DiffHunkView) -> Bool {
        lhs.hunk == rhs.hunk
            && lhs.gutterWidth == rhs.gutterWidth
            && lhs.contentWidth == rhs.contentWidth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hunkHeaderRow(hunk.header)
            ForEach(hunk.lines) { line in
                diffLineRow(line: line)
            }
        }
    }

    private func hunkHeaderRow(_ header: String) -> some View {
        HStack(spacing: 0) {
            Text(header)
                .font(.monoCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minWidth: contentWidth, alignment: .leading)
        .background(Color.surfaceElevated)
    }

    private func diffLineRow(line: DiffLine) -> some View {
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

            Text(DiffLineStyling.sign(line.kind))
                .font(.monoCaption)
                .foregroundStyle(DiffLineStyling.signColor(line.kind))
                .frame(width: 12)

            Text(line.content.isEmpty ? " " : line.content)
                .font(.monoCaption)
                .foregroundStyle(DiffLineStyling.contentColor(line.kind))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .frame(minWidth: contentWidth, alignment: .leading)
        .background(DiffLineStyling.background(line.kind))
    }
}

enum DiffLineStyling {
    static func sign(_ kind: DiffLineKind) -> String {
        switch kind {
        case .addition: "+"
        case .deletion: "-"
        case .context: " "
        }
    }

    static func signColor(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .addition: .diffAddition
        case .deletion: .diffDeletion
        case .context: .textTertiary
        }
    }

    static func contentColor(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .addition: .diffAddition.opacity(0.9)
        case .deletion: .diffDeletion.opacity(0.9)
        case .context: .textSecondary
        }
    }

    static func background(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .addition: .diffAdditionBg
        case .deletion: .diffDeletionBg
        case .context: .clear
        }
    }

    static func lineNumberWidth(maxLine: Int) -> CGFloat {
        let digits = max(String(maxLine).count, 3)
        return CGFloat(digits) * 7 + 4
    }
}
