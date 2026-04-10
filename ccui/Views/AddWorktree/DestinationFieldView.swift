import SwiftUI

struct DestinationFieldView: View {
    @Binding var destinationPath: String
    @Binding var showDestination: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showDestination.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .rotationEffect(.degrees(showDestination ? 90 : 0))
                    Text("Destination")
                        .font(.uiCaption)
                    Spacer()
                    if !showDestination {
                        Text(abbreviatedPath(destinationPath))
                            .font(.monoCaption)
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)

            if showDestination {
                HStack(spacing: 6) {
                    TextField("/path/to/worktree", text: $destinationPath)
                        .textFieldStyle(.plain)
                        .font(.monoCaption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.borderDefault, lineWidth: 1)
                        )

                    Button("Browse") {
                        selectDestination()
                    }
                    .font(.uiLabel)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
        }
    }

    private func abbreviatedPath(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func selectDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose a directory for the worktree"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        destinationPath = url.path(percentEncoded: false)
    }
}
