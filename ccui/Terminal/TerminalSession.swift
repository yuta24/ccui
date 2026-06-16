import AppKit

@MainActor
protocol TerminalSession: AnyObject {
    var id: ObjectIdentifier { get }
    var label: String { get }
    var nsView: NSView { get }
    var isProcessRunning: Bool { get }
    var onProcessTerminated: ((Int32?) -> Void)? { get set }
    var onTitleChanged: ((String) -> Void)? { get set }
    func terminate()
    func refreshDisplay()
    /// Places the image on the system pasteboard and signals the running
    /// process to read it as a pasted image — the same path Claude Code uses
    /// for a manual clipboard paste.
    func pasteImage(_ image: NSImage)
    /// Shows the terminal's built-in find bar for searching the scrollback buffer.
    func showFindBar()
    /// Clears the visible screen and scrollback buffer, similar to Terminal.app's "Clear Buffer".
    func clearScreen()
    /// Sends text to the running process as if the user typed it, followed by a newline.
    func sendText(_ text: String)
    /// Sends multi-line text using bracketed paste escape sequences so embedded newlines
    /// are not treated as separate Enter keypresses by the PTY line discipline.
    func pasteText(_ text: String)
}

extension TerminalSession {
    var id: ObjectIdentifier { ObjectIdentifier(self) }
}
