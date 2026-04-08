import SwiftUI

struct CodeViewerView: View {
    let store: CodeViewerStore

    var body: some View {
        switch store.state {
        case .idle:
            idleView
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(_, let lines):
            codeView(lines: lines)
        case .binary:
            placeholderView(
                icon: "doc.questionmark",
                message: "Cannot preview binary file"
            )
        case .error(let message):
            placeholderView(
                icon: "exclamationmark.triangle",
                message: message
            )
        }
    }

    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("Select a file to view its contents")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func codeView(lines: [String]) -> some View {
        let gutterWidth = lineNumberWidth(totalLines: lines.count)
        return ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 0) {
                        Text("\(index + 1)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: gutterWidth, alignment: .trailing)
                            .padding(.trailing, 12)

                        Text(line.isEmpty ? " " : line)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func lineNumberWidth(totalLines: Int) -> CGFloat {
        let digits = max(String(totalLines).count, 2)
        return CGFloat(digits) * 10
    }

    private func placeholderView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
