import AppKit
@preconcurrency import SwiftTerm

@MainActor
final class SwiftTermSession: TerminalSession {
    private let terminalView: LocalProcessTerminalView

    init(workingDirectory: String) {
        terminalView = LocalProcessTerminalView(frame: .zero)
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        terminalView.startProcess(
            executable: shell,
            currentDirectory: workingDirectory
        )
    }

    var nsView: NSView { terminalView }
}
