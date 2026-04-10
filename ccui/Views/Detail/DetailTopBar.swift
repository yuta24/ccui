import SwiftUI

struct DetailTopBar: View {
    let worktree: Worktree
    let rightPanelStore: RightPanelStore

    var body: some View {
        HStack(spacing: 0) {
            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 9, weight: .medium))
                Text(worktree.displayName)
                    .font(.uiCaption)
            }
            .foregroundStyle(Color.textTertiary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    rightPanelStore.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 10, weight: .medium))
                    Text("Panel")
                        .font(.uiLabel)
                }
                .foregroundStyle(rightPanelStore.isExpanded ? Color.accent : Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(rightPanelStore.isExpanded ? Color.accentSubtle : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
        .frame(height: 36)
        .background(Color.surfaceBase)
    }
}
