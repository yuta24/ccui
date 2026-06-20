import SwiftUI

struct AddressBarView: View {
    let worktree: Worktree
    @Bindable var store: WebViewStore
    let onAddTab: () -> Void
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button {
                store.goBack()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.iconDefault)
                    .foregroundStyle(store.canGoBack ? Color.textSecondary : Color.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!store.canGoBack)
            .help("Go Back")

            Button {
                store.goForward()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.iconDefault)
                    .foregroundStyle(store.canGoForward ? Color.textSecondary : Color.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!store.canGoForward)
            .help("Go Forward")

            Button {
                store.reload()
            } label: {
                Image(systemName: store.isLoading ? "xmark" : "arrow.clockwise")
                    .font(.iconDefault)
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help(store.isLoading ? "Stop" : "Reload")

            Button {
                store.isRegionCaptureActive.toggle()
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.iconDefault)
                    .foregroundStyle(store.isRegionCaptureActive ? Color.accent : Color.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(terminalSessionStore.session(for: worktree) == nil)
            .help("Capture Region to Agent")

            Button(action: onAddTab) {
                Image(systemName: "plus")
                    .font(.iconDefault)
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help("New Tab")

            TextField("Enter URL", text: $inputText)
                .font(.monoField)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.surfaceHover)
                .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.buttonCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: PanelMetrics.buttonCornerRadius)
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
        .background(Color.surfacePrimary)
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
