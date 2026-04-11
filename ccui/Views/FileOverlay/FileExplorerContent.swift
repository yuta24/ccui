import SwiftUI

struct FileExplorerContent: View {
    let store: FileOverlayStore
    let fileTreeStore: FileTreeStore?
    let diffStore: DiffStore
    let codeViewerStore: CodeViewerStore
    let searchStore: SearchStore
    let repositoryPath: String

    @GestureState private var splitDragOffset: CGFloat = 0
    @State private var isCursorPushed = false
    @State private var cachedChangedFiles: [String: DiffFileEntry.Status] = [:]

    var body: some View {
        VStack(spacing: 0) {
            panelHeader

            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            GeometryReader { geometry in
                let totalWidth = geometry.size.width

                HStack(spacing: 0) {
                    treeSection
                        .frame(width: treeWidth(totalWidth: totalWidth))

                    splitResizeHandle(totalWidth: totalWidth)

                    viewerSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .clipped()
        }
        .onAppear {
            cachedChangedFiles = computeChangedFiles()
        }
        .onChange(of: diffStore.stateVersion) { _, _ in
            cachedChangedFiles = computeChangedFiles()
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: 8) {
            Text("Explorer")
                .sectionHeader()

            if let fileTreeStore {
                Button {
                    Task { await fileTreeStore.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Reload file tree")
                .disabled(fileTreeStore.isLoading)
            }

            Spacer()

            Button {
                store.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    // MARK: - Layout Helpers

    private func treeWidth(totalWidth: CGFloat) -> CGFloat {
        let fraction = store.treeFraction + splitDragOffset / totalWidth
        let clampedFraction = min(
            FileOverlayStore.maxTreeFraction,
            max(FileOverlayStore.minTreeFraction, fraction)
        )
        return totalWidth * clampedFraction
    }

    // MARK: - Tree Section

    @ViewBuilder
    private var treeSection: some View {
        if searchStore.isActive {
            SearchPaneView(
                searchStore: searchStore,
                fileOverlayStore: store,
                fileTreeStore: fileTreeStore,
                repositoryPath: repositoryPath
            )
        } else if let fileTreeStore {
            FileTreeView(store: fileTreeStore, changedFiles: cachedChangedFiles)
        } else {
            Color.surfaceBase
        }
    }

    // MARK: - Viewer Section

    @ViewBuilder
    private var viewerSection: some View {
        if let node = store.selectedFile {
            VStack(spacing: 0) {
                viewerHeader(node: node)

                Rectangle()
                    .fill(Color.borderSubtle)
                    .frame(height: 1)

                FileViewerView(
                    node: node,
                    diffStore: diffStore,
                    codeViewerStore: codeViewerStore,
                    repositoryPath: repositoryPath
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(Color.textTertiary.opacity(0.5))
                Text("Select a file to preview")
                    .font(.uiCaption)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.surfaceBase)
        }
    }

    // MARK: - Viewer Header

    private func viewerHeader(node: FileNode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: FileTreeHelpers.fileIcon(for: node.name))
                .font(.system(size: 10))
                .foregroundStyle(Color.accent.opacity(0.7))

            Text(relativePath(for: node.path))
                .font(.uiCaptionMono)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .truncationMode(.head)

            Spacer()

            Button {
                store.deselectFile()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Close file")
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color.surfaceElevated)
    }

    // MARK: - Split Resize Handle

    private func splitResizeHandle(totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(width: 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($splitDragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let delta = value.translation.width / totalWidth
                        let newFraction = store.treeFraction + delta
                        store.treeFraction = min(
                            FileOverlayStore.maxTreeFraction,
                            max(FileOverlayStore.minTreeFraction, newFraction)
                        )
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                    isCursorPushed = true
                } else if isCursorPushed {
                    NSCursor.pop()
                    isCursorPushed = false
                }
            }
            .onDisappear {
                if isCursorPushed {
                    NSCursor.pop()
                    isCursorPushed = false
                }
            }
    }

    // MARK: - Helpers

    private func computeChangedFiles() -> [String: DiffFileEntry.Status] {
        guard case .loaded(let entries) = diffStore.state else { return [:] }
        var result: [String: DiffFileEntry.Status] = [:]
        for entry in entries {
            let path = entry.status == .deleted ? entry.oldPath : entry.newPath
            let fullPath = (repositoryPath as NSString).appendingPathComponent(path)
            result[fullPath] = entry.status
            if entry.status == .renamed {
                let oldFullPath = (repositoryPath as NSString).appendingPathComponent(entry.oldPath)
                result[oldFullPath] = .deleted
            }
        }
        return result
    }

    private func relativePath(for fullPath: String) -> String {
        if fullPath.hasPrefix(repositoryPath + "/") {
            return String(fullPath.dropFirst(repositoryPath.count + 1))
        }
        return fullPath
    }
}
