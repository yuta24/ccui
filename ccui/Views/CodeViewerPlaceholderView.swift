import SwiftUI

struct CodeViewerPlaceholderView: View {
    private let sampleCode = """
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

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(sampleCode)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}
