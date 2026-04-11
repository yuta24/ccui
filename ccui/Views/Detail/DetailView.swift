import SwiftUI

struct DetailView: View {
    let worktree: Worktree
    let fileTreeStore: FileTreeStore?
    let fileOverlayStore: FileOverlayStore
    let codeViewerStore: CodeViewerStore
    @Environment(DiffStore.self) private var diffStore
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @Environment(WorktreeSessionStore.self) private var worktreeSessionStore
    @State private var isSessionEnded = false

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
            launchSession(for: worktree)
            diffStore.reset()
            codeViewerStore.reset()
            startWatching()
        }
        .onDisappear {
            diffStore.stopWatching()
        }
        .onChange(of: worktree) { _, newWorktree in
            isSessionEnded = false
            launchSession(for: newWorktree)
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

    private func launchSession(for wt: Worktree) {
        let isResume = worktreeSessionStore.isResume(for: wt.path)
        let sessionId = worktreeSessionStore.currentSessionId(for: wt.path)
        Task {
            await terminalSessionStore.ensureSession(for: wt, sessionId: sessionId, isResume: isResume)
            if let session = terminalSessionStore.session(for: wt) {
                session.onProcessTerminated = { [weak terminalSessionStore] in
                    guard terminalSessionStore != nil else { return }
                    isSessionEnded = true
                }
            }
        }
    }

    private func regenerateSession() {
        terminalSessionStore.remove(for: worktree.path)
        let sessionId = worktreeSessionStore.createSession(for: worktree.path)
        isSessionEnded = false
        Task {
            await terminalSessionStore.ensureSession(for: worktree, sessionId: sessionId, isResume: false)
            if let session = terminalSessionStore.session(for: worktree) {
                session.onProcessTerminated = { [weak terminalSessionStore] in
                    guard terminalSessionStore != nil else { return }
                    isSessionEnded = true
                }
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
            if isSessionEnded {
                sessionEndedView
            } else if let session = terminalSessionStore.session(for: worktree) {
                TerminalContainerView(session: session, isActive: true)
            } else {
                Color.surfacePrimary
            }
        }
    }

    private var sessionEndedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "terminal")
                .font(.system(size: 32))
                .foregroundStyle(Color.textTertiary)
            Text("Session ended")
                .font(.body)
                .foregroundStyle(Color.textSecondary)
            Button(action: regenerateSession) {
                Text("New Session")
                    .font(.body)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }
}
