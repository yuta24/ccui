import AppKit
@preconcurrency import SwiftTerm

@MainActor
final class SwiftTermSession: TerminalSession, LocalProcessTerminalViewDelegate {
    private let terminalView: LocalProcessTerminalView
    let label: String
    private(set) var isProcessRunning: Bool = true
    var onProcessTerminated: ((Int32?) -> Void)?
    var onTitleChanged: ((String) -> Void)?

    init(workingDirectory: String, label: String, executable: String, args: [String], additionalEnvironment: [String] = []) {
        self.label = label
        terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.changeScrollback(10_000)
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
        terminalView.nativeBackgroundColor = .windowBackgroundColor
        terminalView.nativeForegroundColor = .labelColor
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

    func showFindBar() {
        let menuItem = NSMenuItem()
        menuItem.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        terminalView.performFindPanelAction(menuItem)
    }

    func clearScreen() {
        // Feeds the "erase screen + scrollback, cursor home" sequence directly into the
        // terminal's display buffer, without sending anything to the running process.
        // Goes through TerminalView.feed (not Terminal.feed) so the display and cursor
        // caret position are refreshed via the normal feedPrepare/feedFinish path.
        terminalView.feed(text: "\u{1b}[2J\u{1b}[3J\u{1b}[H")
    }

    func pasteImage(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)

        // Claude Code detects image pastes by watching for Ctrl+V (0x16) and
        // then reading the image directly from the system pasteboard, rather
        // than receiving image bytes through the pty stream.
        terminalView.send(txt: "\u{16}")
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
        let decoded = exitCode.map(Self.decodeWaitStatus)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isProcessRunning = false
            self.onProcessTerminated?(decoded)
        }
    }

    /// SwiftTerm は `waitpid` の生の wait status をそのまま渡してくるため、
    /// シェルの `$?` に相当する値（正常終了は WEXITSTATUS、シグナル終了は 128+signal）に変換する。
    nonisolated private static func decodeWaitStatus(_ status: Int32) -> Int32 {
        let signal = status & 0x7f
        return signal == 0 ? (status >> 8) & 0xff : 128 + signal
    }
}
