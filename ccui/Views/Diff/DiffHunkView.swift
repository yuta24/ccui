import SwiftUI

struct DiffHunkView: View, Equatable {
    let hunk: DiffHunk
    let gutterWidth: CGFloat
    let contentWidth: CGFloat
    let filePath: String
    let onSendToAgent: ((String) -> Void)?

    static func == (lhs: DiffHunkView, rhs: DiffHunkView) -> Bool {
        lhs.hunk == rhs.hunk
            && lhs.gutterWidth == rhs.gutterWidth
            && lhs.contentWidth == rhs.contentWidth
            && lhs.filePath == rhs.filePath
            && (lhs.onSendToAgent == nil) == (rhs.onSendToAgent == nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hunkHeaderRow(hunk.header)
            ForEach(hunk.lines) { line in
                DiffLineRow(
                    line: line,
                    gutterWidth: gutterWidth,
                    contentWidth: contentWidth,
                    filePath: filePath,
                    onSendToAgent: onSendToAgent
                )
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
}

// MARK: - Per-line row with comment support

private struct DiffLineRow: View {
    let line: DiffLine
    let gutterWidth: CGFloat
    let contentWidth: CGFloat
    let filePath: String
    let onSendToAgent: ((String) -> Void)?

    @State private var isHovered = false
    @State private var showingPopover = false
    @State private var commentText = ""

    private var lineRef: String {
        if let n = line.newLineNumber { return "line \(n)" }
        if let o = line.oldLineNumber { return "line \(o) (deleted)" }
        return ""
    }

    var body: some View {
        lineContent
            .overlay(alignment: .leading) {
                if isHovered, onSendToAgent != nil {
                    commentTriggerButton
                        // Position button over the sign column (after both gutter columns and separator)
                        // to avoid obscuring line numbers. Offset = left-pad(8) + gw + gw + trailing-pad(4)
                        // + separator(1) + separator-trailing(8) - center-adjust(2) = gw*2 + 19
                        .padding(.leading, gutterWidth * 2 + 19)
                }
            }
            .onHover { hovering in withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering } }
            .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
                commentPopover
            }
    }

    private var lineContent: some View {
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

    private var commentTriggerButton: some View {
        Button {
            commentText = ""
            showingPopover = true
        } label: {
            Image(systemName: "plus.bubble.fill")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.accent)
                .frame(width: 16, height: 16)
                .background(Color.accent.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .transition(.opacity)
    }

    private var commentPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Context header
            VStack(alignment: .leading, spacing: 4) {
                Text(filePath)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(lineRef)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)

                // Diff line preview
                HStack(spacing: 4) {
                    Text(DiffLineStyling.sign(line.kind))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DiffLineStyling.signColor(line.kind))
                    Text(line.content.isEmpty ? " " : line.content)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DiffLineStyling.contentColor(line.kind))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(DiffLineStyling.background(line.kind).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Divider()

            // Comment input
            TextEditor(text: $commentText)
                .font(.system(size: 12))
                .frame(height: 80)
                .scrollContentBackground(.hidden)
                .background(Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.borderSubtle, lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("キャンセル") {
                    showingPopover = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)

                Button("送信") {
                    sendComment()
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 11, weight: .medium))
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    private func sendComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let sign = DiffLineStyling.sign(line.kind)
        let content = line.content.isEmpty ? "" : line.content
        let message = """
        `\(filePath)` の \(lineRef) についてコメント:
        > \(sign)\(content)

        \(trimmed)
        """
        onSendToAgent?(message)
        showingPopover = false
        commentText = ""
    }
}

// MARK: - Styling helpers

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
