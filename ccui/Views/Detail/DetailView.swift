import SwiftUI

struct DetailView: View {
    let worktree: Worktree
    let fileTreeStore: FileTreeStore?
    let fileOverlayStore: FileOverlayStore
    let codeViewerStore: CodeViewerStore
    let diffStore: DiffStore
    @Environment(TerminalSessionStore.self) private var terminalSessionStore

    var body: some View {
        let _ = fileOverlayStore.isVisible // establish @Observable tracking for onChange
        VStack(spacing: 0) {
            DetailTopBar(worktree: worktree, fileOverlayStore: fileOverlayStore)
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            terminalContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            terminalSessionStore.ensureSession(for: worktree)
            diffStore.reset()
            codeViewerStore.reset()
            startWatching()
        }
        .onDisappear {
            diffStore.stopWatching()
        }
        .onChange(of: worktree) { _, newWorktree in
            terminalSessionStore.ensureSession(for: newWorktree)
            codeViewerStore.reset()
            diffStore.reset()
            fileOverlayStore.deselectFile()
            startWatching()
            if fileOverlayStore.isVisible {
                Task { await diffStore.load(repositoryPath: newWorktree.path) }
            }
        }
        .onChange(of: fileOverlayStore.isVisible) { _, isOpen in
            if isOpen, diffStore.needsLoad {
                Task { await diffStore.load(repositoryPath: worktree.path) }
            }
        }
        .onChange(of: fileTreeStore?.selectedNode) { _, newValue in
            guard let node = newValue, !node.isDirectory else { return }
            fileOverlayStore.selectFile(node)
            fileOverlayStore.open()
            if diffStore.needsLoad {
                Task { await diffStore.load(repositoryPath: worktree.path) }
            }
        }
    }

    private func startWatching() {
        diffStore.startWatching(repositoryPath: worktree.path) { [fileOverlayStore] in
            fileOverlayStore.isVisible
        }
    }

    // MARK: - Terminal Content

    private var terminalContent: some View {
        Group {
            if let session = terminalSessionStore.session(for: worktree) {
                TerminalContainerView(session: session, isActive: true)
            } else {
                Color.surfacePrimary
            }
        }
    }
}
