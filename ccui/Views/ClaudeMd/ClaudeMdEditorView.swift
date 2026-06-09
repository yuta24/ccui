import SwiftUI

struct ClaudeMdEditorView: View {
    @Bindable var store: ClaudeMdStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let level = store.selectedLevel {
                editorHeader(level)
                Rectangle()
                    .fill(Color.borderSubtle)
                    .frame(height: 1)
                textEditor
            } else {
                emptyState
            }
        }
    }

    // MARK: - Header

    private func editorHeader(_ level: ClaudeMdLevel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(level.rawValue)
                    .font(.uiLabel)
                    .foregroundStyle(Color.textPrimary)
                Text(level.description)
                    .font(.uiCaption)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()

            if store.isDirty {
                Button {
                    store.save()
                } label: {
                    Text("Save")
                        .font(.uiCaption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Editor

    private var textEditor: some View {
        TextEditor(text: $store.editorContent)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .foregroundStyle(Color.textPrimary)
            .padding(4)
            .onChange(of: store.editorContent) { _, newValue in
                if newValue != store.loadedContent {
                    store.isDirty = true
                }
            }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 24))
                .foregroundStyle(Color.textSecondary)
            Text("Select a CLAUDE.md file")
                .font(.uiCaption)
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
