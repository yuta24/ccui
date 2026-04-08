import AppKit

@MainActor
protocol TerminalSession: AnyObject {
    var nsView: NSView { get }
}
