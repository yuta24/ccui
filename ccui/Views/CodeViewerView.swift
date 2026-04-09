import SwiftUI

struct CodeViewerView: View {
    let store: CodeViewerStore

    var body: some View {
        switch store.state {
        case .idle:
            idleView
        case .loading:
            ProgressView()
                .controlSize(.small)
                .tint(Color.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.surfacePrimary)
        case .loaded(_, let lines):
            codeView(lines: lines)
        case .binary:
            placeholderView(icon: "doc.questionmark", message: "Binary file")
        case .error(let message):
            placeholderView(icon: "exclamationmark.triangle", message: message)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "curlybraces")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)
            Text("Select a file to view")
                .font(.uiLabel)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }

    // MARK: - Code View

    private func codeView(lines: [String]) -> some View {
        let gutterWidth = lineNumberWidth(totalLines: lines.count)

        return ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 0) {
                        // Line number gutter
                        Text("\(index + 1)")
                            .font(.monoSmall)
                            .foregroundStyle(Color.gutterText)
                            .frame(width: gutterWidth, alignment: .trailing)
                            .padding(.trailing, 16)

                        // Gutter separator
                        Rectangle()
                            .fill(Color.borderSubtle)
                            .frame(width: 1)
                            .padding(.trailing, 12)

                        // Code content
                        Text(line.isEmpty ? " " : line)
                            .font(.monoSmall)
                            .foregroundStyle(Color.textPrimary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.leading, 8)
                    .padding(.vertical, 1)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.surfacePrimary)
    }

    private func lineNumberWidth(totalLines: Int) -> CGFloat {
        let digits = max(String(totalLines).count, 3)
        return CGFloat(digits) * 8 + 4
    }

    // MARK: - Placeholder

    private func placeholderView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)
            Text(message)
                .font(.uiLabel)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }
}
