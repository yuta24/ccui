import SwiftUI

struct ClaudeMdListView: View {
    @Bindable var store: ClaudeMdStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.files) { file in
                fileRow(file)
                if file.level != ClaudeMdLevel.allCases.last {
                    Rectangle()
                        .fill(Color.borderSubtle)
                        .frame(height: 1)
                }
            }
        }
    }

    private func fileRow(_ file: ClaudeMdFile) -> some View {
        Button {
            if file.exists {
                store.select(file.level)
            } else {
                store.createFile(at: file.level)
            }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(file.level.rawValue)
                            .font(.uiLabel)
                            .foregroundStyle(file.exists ? Color.textPrimary : Color.textTertiary)

                        if store.selectedLevel == file.level && store.isDirty {
                            Circle()
                                .fill(Color.accent)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Text(abbreviatePath(file.path))
                        .font(.uiCaptionMono)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if file.exists {
                    if let date = file.modifiedAt {
                        Text(date, style: .relative)
                            .font(.uiCaption)
                            .foregroundStyle(Color.textTertiary)
                    }
                } else {
                    Text("Create")
                        .font(.uiCaption)
                        .foregroundStyle(Color.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(store.selectedLevel == file.level ? Color.surfaceHover : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func abbreviatePath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
