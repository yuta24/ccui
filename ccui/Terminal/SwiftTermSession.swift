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
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["LANG"] = "en_US.UTF-8"
        for entry in additionalEnvironment {
            let parts = entry.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                env[String(parts[0])] = String(parts[1])
            }
        }
        env["CCUI_SESSION"] = "1"
        let envStrings = env.map { "\($0.key)=\($0.value)" }
        terminalView.processDelegate = self
        terminalView.startProcess(
            executable: executable,
            args: args,
            environment: envStrings,
            currentDirectory: workingDirectory
        )
    }

    var nsView: NSView { terminalView }

    func terminate() {
        terminalView.terminate()
    }

    func refreshDisplay() {
        let t = terminalView.getTerminal()
        t.refresh(startRow: 0, endRow: t.rows - 1)
        terminalView.setNeedsDisplay(terminalView.bounds)
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
