import SwiftUI

struct AgentStatusBadge: View {
    let activity: SessionActivity
    let pendingAttentionCount: Int

    var body: some View {
        if activity != .idle || pendingAttentionCount > 0 {
            HStack(spacing: 3) {
                if activity != .idle {
                    Image(systemName: activity.systemImageName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(activity.color)
                }
                if pendingAttentionCount > 0 {
                    Circle()
                        .fill(Color.accent)
                        .frame(width: 5, height: 5)
                }
            }
        }
    }
}
