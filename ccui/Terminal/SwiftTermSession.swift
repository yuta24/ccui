import AppKit
@preconcurrency import SwiftTerm

@MainActor
final class SwiftTermSession: TerminalSession, LocalProcessTerminalViewDelegate {
    private let terminalView: LocalProcessTerminalView
    let label: String
    private(set) var isProcessRunning: Bool = true
    var onProcessTerminated: (() -> Void)?

    init(workingDirectory: String, label: String, executable: String, args: [String]) {
        self.label = label
        terminalView = LocalProcessTerminalView(frame: .zero)
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
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
    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isProcessRunning = false
            self.onProcessTerminated?()
        }
    }
}
