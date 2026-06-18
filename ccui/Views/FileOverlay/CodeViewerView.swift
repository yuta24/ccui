import SwiftUI
import CodeEditSourceEditor
import CodeEditLanguages

struct CodeViewerView: View {
    let store: CodeViewerStore

    @State private var editorState = SourceEditorState()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppSettingsStore.self) private var settingsStore

    var body: some View {
        Group {
            switch store.state {
            case .idle:
                idleView
            case .loading:
                PulsingDotsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.surfacePrimary)
            case .loaded(let content, let path):
                editorView(content: content, path: path)
            case .binary:
                placeholderView(icon: "doc.questionmark", message: "Binary file")
            case .error(let message):
                placeholderView(icon: "exclamationmark.triangle", message: message)
            }
        }
        // EditorTheme.monochrome は NSColor を解決時点の appearance で固定 RGB に
        // 変換するため、ライト/ダーク切替時にエディタを再生成して再解決させる。
        .id("\(store.loadedPath ?? "")-\(colorScheme)-\(settingsStore.fontName)-\(settingsStore.fontSize)")
        .onChange(of: store.loadedPath) {
            editorState = SourceEditorState()
        }
    }

    // MARK: - Editor View

    private func editorView(content: String, path: String) -> some View {
        let binding = Binding<String>(
            get: { content },
            set: { _ in }
        )
        let language = CodeLanguage.detectLanguageFrom(url: URL(fileURLWithPath: path))

        return SourceEditor(
            binding,
            language: language,
            configuration: SourceEditorConfiguration(
                appearance: .init(
                    theme: .monochrome,
                    font: settingsStore.resolvedNSFont,
                    lineHeightMultiple: 1.4,
                    wrapLines: false,
                    bracketPairEmphasis: nil
                ),
                behavior: .init(
                    isEditable: false,
                    isSelectable: true
                ),
                peripherals: .init(
                    showGutter: true,
                    showMinimap: false,
                    showFoldingRibbon: false
                )
            ),
            state: $editorState
        )
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
