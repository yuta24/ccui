import SwiftUI

struct SidebarEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.emptyStateIcon)
                .foregroundStyle(Color.textTertiary)

            Text("Add a repository\nto get started")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Spacer()
        }
    }
}
