import SwiftUI

struct DiffViewerView: View {
    @Environment(DiffStore.self) private var store
    let repositoryPath: String

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

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
            DiffModeToggle(currentMode: store.mode) { mode in
                Task { await store.load(repositoryPath: repositoryPath, mode: mode) }
            }

            Spacer()

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

            if let path = store.selectedFilePath,
               let entry = entries.first(where: { $0.newPath == path || $0.oldPath == path }) {
                DiffFileContentView(entry: entry)
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
                ForEach(entries) { entry in
                    DiffFileRowView(
                        entry: entry,
                        isSelected: store.selectedFilePath == entry.newPath,
                        onSelect: { store.selectFile(entry.newPath) }
                    )
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        }
        .background(Color.surfaceBase)
    }
}
