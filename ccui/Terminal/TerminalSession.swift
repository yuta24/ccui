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
}

extension TerminalSession {
    var id: ObjectIdentifier { ObjectIdentifier(self) }
}
