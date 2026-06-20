import SwiftUI

struct QuickOpenRowView: View {
    let result: QuickOpenResult
    let isSelected: Bool
    let repositoryPath: String

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: FileTreeHelpers.fileIcon(for: result.node.name))
                .font(.iconMedium)
                .foregroundStyle(Color.accent.opacity(Opacity.mutedAccent))
                .frame(width: 16)

            highlightedName

            Spacer()

            Text(relativePath)
                .font(.uiCaptionMono)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: PanelMetrics.buttonCornerRadius)
                .fill(isSelected ? Color.accentSubtle : (isHovered ? Color.surfaceHover : Color.clear))
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var highlightedName: some View {
        let name = result.node.name
        let matchedSet = Set(result.matchedIndices)

        return Text(buildAttributedName(name: name, matchedSet: matchedSet))
            .font(.uiLabel)
            .lineLimit(1)
    }

    private func buildAttributedName(name: String, matchedSet: Set<String.Index>) -> AttributedString {
        var attributed = AttributedString()
        for index in name.indices {
            var ch = AttributedString(String(name[index]))
            if matchedSet.contains(index) {
                ch.foregroundColor = Color.accent
            } else {
                ch.foregroundColor = Color.textPrimary
            }
            attributed += ch
        }
        return attributed
    }

    private var relativePath: String {
        let dir = (result.node.path as NSString).deletingLastPathComponent
        if dir.hasPrefix(repositoryPath + "/") {
            return String(dir.dropFirst(repositoryPath.count + 1))
        }
        return dir
    }
}
