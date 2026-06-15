import SwiftUI

struct WorktreeRowView: View {
    let worktree: Worktree
    let isSelected: Bool
    let summary: ClaudeEventStore.WorktreeAgentSummary
    let statusCount: Int?
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onSelect()
        } label: {
            rowLabel
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var rowLabel: some View {
        if isSelected {
            rowInner
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentSubtle))
        } else if isHovered {
            rowInner
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.surfaceHover))
        } else {
            rowInner
        }
    }

    /// この worktree の行・関連パネルで共通して使うインジケーターバーの色。
    /// アクティブ/要対応中はアクティビティ色、メイン worktree は accent、それ以外は控えめなグレー。
    static func indicatorColor(worktree: Worktree, summary: ClaudeEventStore.WorktreeAgentSummary) -> Color {
        let isHighlighted = summary.activity.isActive || summary.pendingAttentionCount > 0 || summary.hasUnacknowledgedFinished
        return isHighlighted ? summary.activity.color :
            worktree.isMain ? Color.accent.opacity(0.8) : Color.textTertiary.opacity(0.5)
    }

    private var rowInner: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Self.indicatorColor(worktree: worktree, summary: summary))
                .frame(width: 4, height: 16)

            Text(worktree.displayName)
                .font(.uiLabel)
                .foregroundStyle(Color.textPrimary)
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
    }
}
