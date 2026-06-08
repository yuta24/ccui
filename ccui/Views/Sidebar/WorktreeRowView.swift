import SwiftUI

struct WorktreeRowView: View {
    let worktree: Worktree
    let isSelected: Bool
    let summary: ClaudeEventStore.WorktreeAgentSummary
    let isHighlighted: Bool
    let statusCount: Int?
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        isHighlighted ? summary.activity.color :
                        worktree.isMain ? Color.accent.opacity(0.8) : Color.textTertiary.opacity(0.5)
                    )
                    .frame(width: 4, height: 16)

                Text(worktree.displayName)
                    .font(.uiLabel)
                    .foregroundStyle(isSelected || isHighlighted ? Color.textPrimary : Color.textSecondary)
                    .lineLimit(1)

                Spacer()

                AgentStatusBadge(activity: summary.activity, pendingAttentionCount: summary.pendingAttentionCount)

                if let count = statusCount {
                    if count > 0 {
                        Text("\(count)")
                            .font(.uiCaptionMono)
                            .foregroundStyle(Color.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Circle()
                            .fill(Color.statusClean)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        isSelected ? Color.surfaceElevated :
                        isHighlighted ? summary.activity.color.opacity(0.08) :
                        isHovered ? Color.surfaceHover : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        isSelected ? Color.borderDefault :
                        isHighlighted ? summary.activity.color.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
