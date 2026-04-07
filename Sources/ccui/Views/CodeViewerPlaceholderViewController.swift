import AppKit

final class CodeViewerPlaceholderViewController: NSViewController {
    override func loadView() {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        let sampleCode = """
        import Foundation

        struct App {
            let name: String
            let version: String

            func run() {
                print("\\(name) v\\(version) is running")
            }
        }

        // Code viewer — Tree-sitter syntax highlighting pending
        """

        textView.string = sampleCode

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        textView.autoresizingMask = [.width]

        view = scrollView
    }
}
