import SwiftUI

struct DiffFileSection: View {
    let entry: DiffFileEntry
    let contentWidth: CGFloat
    let onSendToAgent: ((String) -> Void)?

    @Environment(AppSettingsStore.self) private var settingsStore
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

                DiffStatusBadge(status: entry.status)

                Text(displayPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(settingsStore.resolvedFont)
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
                .font(.iconDefault)
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
        let gutterWidth = DiffLineStyling.lineNumberWidth(maxLine: entry.maxLineNumber)

        return ScrollView(.horizontal, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(entry.hunks) { hunk in
                    DiffHunkView(
                        hunk: hunk,
                        gutterWidth: gutterWidth,
                        contentWidth: contentWidth,
                        filePath: displayPath,
                        onSendToAgent: onSendToAgent
                    )
                    .equatable()
                }
            }
            .frame(minWidth: contentWidth, alignment: .leading)
        }
        .environment(\.codeFont, settingsStore.resolvedFont)
        .background(Color.surfacePrimary)
    }

    // MARK: - Helpers

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
