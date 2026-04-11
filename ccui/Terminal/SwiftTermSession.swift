import AppKit
@preconcurrency import SwiftTerm

@MainActor
final class SwiftTermSession: TerminalSession {
    private let terminalView: LocalProcessTerminalView
    let label: String

    init(workingDirectory: String, label: String) {
        self.label = label
        terminalView = LocalProcessTerminalView(frame: .zero)
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("CCUI_SESSION=1")
        terminalView.startProcess(
            executable: shell,
            args: ["-l"],
            environment: env,
            currentDirectory: workingDirectory
        )
    }

    var nsView: NSView { terminalView }

    func terminate() {
        terminalView.terminate()
    }
}
