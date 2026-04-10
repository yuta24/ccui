import SwiftUI

struct TerminalContainerView: NSViewRepresentable {
    let session: any TerminalSession
    var isActive: Bool = true

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.autoresizesSubviews = true
        let terminal = session.nsView
        terminal.autoresizingMask = [.width, .height]
        terminal.frame = container.bounds
        container.addSubview(terminal)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let terminal = session.nsView
        if terminal.superview !== nsView {
            nsView.subviews.forEach { $0.removeFromSuperview() }
            terminal.autoresizingMask = [.width, .height]
            terminal.frame = nsView.bounds
            nsView.addSubview(terminal)
        }
        if !isActive, nsView.window?.firstResponder === terminal {
            nsView.window?.makeFirstResponder(nil)
        }
    }
}
