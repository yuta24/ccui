import SwiftUI

struct DiffViewerView: View {
    let store: DiffStore
    let repositoryPath: String

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            // Content
            switch store.state {
            case .idle:
                idleView
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.surfacePrimary)
            case .loaded(let entries):
                if entries.isEmpty {
                    placeholderView(
                        icon: "checkmark.circle",
                        message: store.mode == .staged ? "No staged changes" : "No unstaged changes"
                    )
                } else {
                    diffSplitView(entries: entries)
                }
            case .error(let message):
                placeholderView(icon: "exclamationmark.triangle", message: message)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            // Mode toggle
            HStack(spacing: 0) {
                modeButton(.staged)
                modeButton(.unstaged)
            }
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.borderSubtle, lineWidth: 1)
            )

            Spacer()

            // Refresh
            Button {
                Task { await store.load(repositoryPath: repositoryPath) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Refresh diff")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.surfaceBase)
    }

    private func modeButton(_ mode: DiffStore.DiffMode) -> some View {
        let isSelected = store.mode == mode

        return Button {
            Task { await store.load(repositoryPath: repositoryPath, mode: mode) }
        } label: {
            Text(mode.rawValue)
                .font(.uiLabel)
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.surfaceHover : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)
            Text("Open panel to load diff")
                .font(.uiLabel)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }

    private func placeholderView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)
            Text(message)
                .font(.uiLabel)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }

    // MARK: - Split View

    private func diffSplitView(entries: [DiffFileEntry]) -> some View {
        HSplitView {
            fileList(entries: entries)
                .frame(minWidth: 180, idealWidth: 240, maxWidth: 350)

            if let index = store.selectedFileIndex, entries.indices.contains(index) {
                DiffFileContentView(entry: entries[index])
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundStyle(Color.textTertiary)
                    Text("Select a file")
                        .font(.uiLabel)
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.surfacePrimary)
            }
        }
    }

    private func fileList(entries: [DiffFileEntry]) -> some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    DiffFileRowView(
                        entry: entry,
                        isSelected: store.selectedFileIndex == index,
                        onSelect: { store.selectFile(index) }
                    )
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        }
        .background(Color.surfaceBase)
    }
}

// MARK: - File Row

private struct DiffFileRowView: View {
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
        case .added, .modified:
            entry.newPath
        }
    }

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 8) {
                // Status indicator
                statusBadge

                // File path
                Text(displayPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.monoCaption)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)

                Spacer()

                // Stats
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
        }
    }

    private var statusColor: Color {
        switch entry.status {
        case .added: .diffAddition
        case .modified: .accent
        case .deleted: .diffDeletion
        case .renamed: .statusRenamed
        }
    }

    private var statsView: some View {
        let additions = entry.hunks.flatMap(\.lines).filter { $0.kind == .addition }.count
        let deletions = entry.hunks.flatMap(\.lines).filter { $0.kind == .deletion }.count

        return HStack(spacing: 4) {
            if additions > 0 {
                Text("+\(additions)")
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.diffAddition)
            }
            if deletions > 0 {
                Text("-\(deletions)")
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.diffDeletion)
            }
        }
    }
}

// MARK: - Diff Content

struct DiffFileContentView: View {
    let entry: DiffFileEntry

    var body: some View {
        if entry.isBinary {
            VStack(spacing: 12) {
                Image(systemName: "doc.questionmark")
                    .font(.system(size: 28, weight: .ultraLight))
                    .foregroundStyle(Color.textTertiary)
                Text("Binary file changed")
                    .font(.uiLabel)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.surfacePrimary)
        } else if entry.hunks.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28, weight: .ultraLight))
                    .foregroundStyle(Color.textTertiary)
                Text("File mode or metadata changed")
                    .font(.uiLabel)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.surfacePrimary)
        } else {
            diffLines
        }
    }

    private var diffLines: some View {
        let maxOldLine = entry.hunks.flatMap(\.lines).compactMap(\.oldLineNumber).max() ?? 0
        let maxNewLine = entry.hunks.flatMap(\.lines).compactMap(\.newLineNumber).max() ?? 0
        let gutterWidth = lineNumberWidth(maxLine: max(maxOldLine, maxNewLine))

        return GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(entry.hunks) { hunk in
                        hunkHeaderRow(hunk.header)
                        ForEach(hunk.lines) { line in
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
            // Old line number
            Text(line.oldLineNumber.map(String.init) ?? "")
                .font(.monoCaption)
                .foregroundStyle(Color.gutterText)
                .frame(width: gutterWidth, alignment: .trailing)

            // New line number
            Text(line.newLineNumber.map(String.init) ?? "")
                .font(.monoCaption)
                .foregroundStyle(Color.gutterText)
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 4)

            // Gutter separator
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(width: 1)
                .padding(.trailing, 8)

            // Sign
            Text(lineSign(line.kind))
                .font(.monoCaption)
                .foregroundStyle(lineColor(line.kind))
                .frame(width: 12)

            // Content
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
        case .context, .hunkHeader: " "
        }
    }

    private func lineColor(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .addition: .diffAddition
        case .deletion: .diffDeletion
        case .context, .hunkHeader: .textTertiary
        }
    }

    private func contentColor(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .addition: .diffAddition.opacity(0.9)
        case .deletion: .diffDeletion.opacity(0.9)
        case .context: .textSecondary
        case .hunkHeader: .textTertiary
        }
    }

    private func lineBackground(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .addition: .diffAdditionBg
        case .deletion: .diffDeletionBg
        case .context, .hunkHeader: .clear
        }
    }

    private func lineNumberWidth(maxLine: Int) -> CGFloat {
        let digits = max(String(maxLine).count, 3)
        return CGFloat(digits) * 7 + 4
    }
}
