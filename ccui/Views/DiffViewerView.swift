import SwiftUI

struct DiffViewerView: View {
    let store: DiffStore
    let repositoryPath: String

    var body: some View {
        VStack(spacing: 0) {
            modePicker
            Divider()

            switch store.state {
            case .idle:
                idleView
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let entries):
                if entries.isEmpty {
                    placeholderView(icon: "tray", message: store.mode == .staged ? "No staged changes" : "No unstaged changes")
                } else {
                    diffSplitView(entries: entries)
                }
            case .error(let message):
                placeholderView(icon: "exclamationmark.triangle", message: message)
            }
        }
    }

    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("Switch to this tab to load diff")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { store.mode },
            set: { newMode in
                Task { await store.load(repositoryPath: repositoryPath, mode: newMode) }
            }
        )) {
            ForEach(DiffStore.DiffMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 200)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func diffSplitView(entries: [DiffFileEntry]) -> some View {
        HSplitView {
            fileList(entries: entries)
                .frame(minWidth: 180, idealWidth: 240, maxWidth: 350)

            if let index = store.selectedFileIndex, entries.indices.contains(index) {
                DiffFileContentView(entry: entries[index])
            } else {
                placeholderView(icon: "doc.text", message: "Select a file")
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.load(repositoryPath: repositoryPath) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh diff")
            }
        }
    }

    private func fileList(entries: [DiffFileEntry]) -> some View {
        List(selection: Binding(
            get: { store.selectedFileIndex },
            set: { store.selectFile($0) }
        )) {
            ForEach(entries) { entry in
                DiffFileRowView(entry: entry)
                    .tag(entry.id)
            }
        }
        .listStyle(.sidebar)
    }

    private func placeholderView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - File Row

private struct DiffFileRowView: View {
    let entry: DiffFileEntry

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
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(displayPath)
                .lineLimit(1)
                .truncationMode(.middle)
                .font(.system(.body, design: .monospaced))
        }
    }

    private var statusColor: Color {
        switch entry.status {
        case .added: .green
        case .modified: .yellow
        case .deleted: .red
        case .renamed: .blue
        }
    }
}

// MARK: - Diff Content

private struct DiffFileContentView: View {
    let entry: DiffFileEntry

    var body: some View {
        if entry.isBinary {
            VStack(spacing: 12) {
                Image(systemName: "doc.questionmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Binary file changed")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if entry.hunks.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("File mode or metadata changed")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            diffLines
        }
    }

    private var diffLines: some View {
        let maxOldLine = entry.hunks.flatMap(\.lines).compactMap(\.oldLineNumber).max() ?? 0
        let maxNewLine = entry.hunks.flatMap(\.lines).compactMap(\.newLineNumber).max() ?? 0
        let gutterWidth = lineNumberWidth(maxLine: max(maxOldLine, maxNewLine))

        return ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(entry.hunks) { hunk in
                    hunkHeaderRow(hunk.header)
                    ForEach(hunk.lines) { line in
                        diffLineRow(line: line, gutterWidth: gutterWidth)
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func hunkHeaderRow(_ header: String) -> some View {
        Text(header)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .separatorColor).opacity(0.15))
    }

    private func diffLineRow(line: DiffLine, gutterWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(line.oldLineNumber.map(String.init) ?? "")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: gutterWidth, alignment: .trailing)

            Text(line.newLineNumber.map(String.init) ?? "")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 8)

            Text(lineSign(line.kind))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(lineColor(line.kind))
                .frame(width: 14)

            Text(line.content.isEmpty ? " " : line.content)
                .font(.system(.body, design: .monospaced))
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
        case .addition: .green
        case .deletion: .red
        case .context, .hunkHeader: .secondary
        }
    }

    private func lineBackground(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .addition: Color.green.opacity(0.1)
        case .deletion: Color.red.opacity(0.1)
        case .context, .hunkHeader: .clear
        }
    }

    private func lineNumberWidth(maxLine: Int) -> CGFloat {
        let digits = max(String(maxLine).count, 3)
        return CGFloat(digits) * 9 + 4
    }
}
