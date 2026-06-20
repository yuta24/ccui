import SwiftUI

struct SidebarEmptyStateView: View {
    var onAddRepository: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.emptyStateIconLarge)
                .foregroundStyle(Color.textTertiary)

            VStack(spacing: 12) {
                Text("No repositories")
                    .font(.uiLabel)
                    .foregroundStyle(Color.textSecondary)

                if let onAddRepository {
                    Button(action: onAddRepository) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.iconSmall)
                            Text("Add Repository")
                                .font(.uiCaption)
                        }
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.accentSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.inputCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
    }
}
