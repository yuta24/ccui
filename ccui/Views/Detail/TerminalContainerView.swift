import SwiftUI

struct TerminalContainerView: NSViewRepresentable {
    let session: any TerminalSession
    var isActive: Bool = true

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.autoresizesSubviews = true
        embedTerminal(in: container)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let terminal = session.nsView
        if terminal.superview !== nsView {
            embedTerminal(in: nsView)
        }
        if !isActive, nsView.window?.firstResponder === terminal {
            nsView.window?.makeFirstResponder(nil)
        }
    }

    private func embedTerminal(in container: NSView) {
        container.subviews.forEach { $0.removeFromSuperview() }
        let terminal = session.nsView
        // Use Auto Layout to avoid setting frame to .zero on the terminal view.
        // Setting frame to .zero triggers processSizeChange → terminal.resize(cols: 2, rows: 1)
        // which sends SIGWINCH to the child process, causing unnecessary full redraws
        // and potential state corruption when rapidly switching tabs.
        terminal.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            terminal.topAnchor.constraint(equalTo: container.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        // Force full refresh after re-parenting so stale content is redrawn.
        // While detached, updateDisplay consumes terminal update ranges via
        // clearUpdateRange() but setNeedsDisplay is a no-op, leaving the view stale.
        session.refreshDisplay()
    }
}
