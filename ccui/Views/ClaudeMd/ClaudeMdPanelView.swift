import SwiftUI

struct ClaudeMdPanelView: View {
    let repositoryPath: String
    @Bindable var store: ClaudeMdStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            ClaudeMdListView(store: store)
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            ClaudeMdEditorView(store: store)
                .frame(maxHeight: .infinity)

            if let error = store.lastError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.diffDeletion)
                    Text(error)
                        .font(.uiCaption)
                        .foregroundStyle(Color.diffDeletion)
                    Spacer()
                    Button {
                        store.lastError = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.diffDeletionBg)
            }
        }
        .frame(width: 360)
        .background(Color.surfacePrimary)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.borderSubtle).frame(width: 1)
        }
        .onAppear {
            store.load(repositoryPath: repositoryPath)
        }
        .onChange(of: repositoryPath) { _, newPath in
            store.load(repositoryPath: newPath)
        }
    }

    private var header: some View {
        HStack {
            Text("CLAUDE.md")
                .sectionHeader()
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
