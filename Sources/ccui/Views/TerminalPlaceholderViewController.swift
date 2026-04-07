import AppKit

final class TerminalPlaceholderViewController: NSViewController {
    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor

        let label = NSTextField(labelWithString: "Terminal — libghostty integration pending")
        label.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        label.textColor = .green
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        view = container
    }
}
