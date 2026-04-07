import AppKit

final class DiffViewerPlaceholderViewController: NSViewController {
    override func loadView() {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let leftScrollView = makeTextScrollView(content: """
        func greet(name: String) {
            print("Hello, \\(name)")
        }

        // Old version
        """, backgroundColor: NSColor.systemRed.withAlphaComponent(0.05))

        let rightScrollView = makeTextScrollView(content: """
        func greet(name: String, greeting: String = "Hello") {
            print("\\(greeting), \\(name)")
        }

        // New version
        """, backgroundColor: NSColor.systemGreen.withAlphaComponent(0.05))

        splitView.addSubview(leftScrollView)
        splitView.addSubview(rightScrollView)

        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 1)

        view = splitView
    }

    private func makeTextScrollView(content: String, backgroundColor: NSColor) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = backgroundColor
        textView.textColor = .textColor
        textView.string = content
        textView.autoresizingMask = [.width, .height]

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true

        return scrollView
    }
}
