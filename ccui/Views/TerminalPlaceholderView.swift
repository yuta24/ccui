import SwiftUI

struct TerminalPlaceholderView: View {
    let repository: Repository

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 8) {
                Text("Terminal — libghostty integration pending")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.green)
                Text(repository.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.green.opacity(0.6))
            }
        }
    }
}
