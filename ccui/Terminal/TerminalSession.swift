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
}

extension TerminalSession {
    var id: ObjectIdentifier { ObjectIdentifier(self) }
}
