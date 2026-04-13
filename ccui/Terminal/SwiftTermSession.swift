import AppKit
@preconcurrency import SwiftTerm

@MainActor
final class SwiftTermSession: TerminalSession, LocalProcessTerminalViewDelegate {
    private let terminalView: LocalProcessTerminalView
    let label: String
    private(set) var isProcessRunning: Bool = true
    var onProcessTerminated: (() -> Void)?
    var onTitleChanged: ((String) -> Void)?

    init(workingDirectory: String, label: String, executable: String, args: [String], additionalEnvironment: [String] = []) {
        self.label = label
        terminalView = LocalProcessTerminalView(frame: .zero)
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append(contentsOf: additionalEnvironment)
        env.append("CCUI_SESSION=1")
        terminalView.processDelegate = self
        terminalView.startProcess(
            executable: executable,
            args: args,
            environment: env,
            currentDirectory: workingDirectory
        )
    }

    var nsView: NSView { terminalView }

    func terminate() {
        terminalView.terminate()
    }

    // MARK: - LocalProcessTerminalViewDelegate

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        // Claude Code のタイトル形式: "✳ Claude Code" → "⠂ タスク概要" → "✳ タスク概要"
        // 先頭のステータスインジケーター + スペースを除去し、"Claude Code" 以外をタイトルとして通知
        let cleaned = title.drop(while: { !$0.isASCII && !$0.isLetter }).trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned != "Claude Code" else { return }
        Task { @MainActor [weak self] in
            self?.onTitleChanged?(cleaned)
        }
    }

    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isProcessRunning = false
            self.onProcessTerminated?()
        }
    }
}
