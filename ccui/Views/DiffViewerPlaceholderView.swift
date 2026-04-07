import SwiftUI

struct DiffViewerPlaceholderView: View {
    private let oldCode = """
    func greet(name: String) {
        print("Hello, \\(name)")
    }
    """

    private let newCode = """
    func greet(name: String, greeting: String = "Hello") {
        print("\\(greeting), \\(name)")
    }
    """

    var body: some View {
        HSplitView {
            ScrollView([.horizontal, .vertical]) {
                Text(oldCode)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
            }
            .background(Color.red.opacity(0.05))

            ScrollView([.horizontal, .vertical]) {
                Text(newCode)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
            }
            .background(Color.green.opacity(0.05))
        }
    }
}
