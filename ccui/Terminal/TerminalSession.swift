import AppKit

@MainActor
protocol TerminalSession: AnyObject {
    var id: ObjectIdentifier { get }
    var label: String { get }
    var nsView: NSView { get }
    func terminate()
}

extension TerminalSession {
    var id: ObjectIdentifier { ObjectIdentifier(self) }
}
