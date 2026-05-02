import SwiftUI

struct AddressBarView: View {
    @Bindable var store: WebViewStore
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button {
                store.goBack()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(store.canGoBack ? Color.textSecondary : Color.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!store.canGoBack)
            .help("Go Back")

            Button {
                store.goForward()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(store.canGoForward ? Color.textSecondary : Color.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!store.canGoForward)
            .help("Go Forward")

            Button {
                store.reload()
            } label: {
                Image(systemName: store.isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help(store.isLoading ? "Stop" : "Reload")

            TextField("Enter URL", text: $inputText)
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(.plain)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.surfaceBase)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.borderSubtle, lineWidth: 1)
                )
                .focused($isFocused)
                .onSubmit {
                    submit(inputText)
                }
                .onAppear {
                    inputText = store.urlString
                }
                .onChange(of: store.urlString) { _, newValue in
                    if !isFocused {
                        inputText = newValue
                    }
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.surfaceBase)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderSubtle).frame(height: 1)
        }
    }

    private func submit(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Reject any input that explicitly uses a non-web scheme.
        if let schemeRange = trimmed.range(of: "://") {
            let scheme = trimmed[..<schemeRange.lowerBound].lowercased()
            guard scheme == "http" || scheme == "https" else { return }
            store.load(urlString: trimmed)
            return
        }

        if trimmed.hasPrefix("about:") {
            store.load(urlString: trimmed)
            return
        }

        store.load(urlString: "https://\(trimmed)")
    }
}
