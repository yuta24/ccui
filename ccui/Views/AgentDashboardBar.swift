import SwiftUI

struct AgentDashboardBar: View {
    @Environment(ClaudeEventStore.self) private var claudeEventStore

    var body: some View {
        let active = claudeEventStore.activeAgentCount
        let done = claudeEventStore.doneAgentCount
        let notified = claudeEventStore.notifiedAgentCount
        let hasStatus = !claudeEventStore.sessions.isEmpty && (active > 0 || done > 0 || notified > 0)

        HStack(spacing: 12) {
            if let loadError = claudeEventStore.loadError {
                statusItem(
                    icon: "exclamationmark.triangle.fill",
                    color: .diffDeletion,
                    label: loadError
                )
            } else if hasStatus {
                if active > 0 {
                    statusItem(
                        icon: "hammer",
                        color: .statusRenamed,
                        label: "\(active) active"
                    )
                }

                if notified > 0 {
                    statusItem(
                        icon: "bell.fill",
                        color: .accent,
                        label: "\(notified) notified"
                    )
                }

                if done > 0 {
                    statusItem(
                        icon: "checkmark.circle.fill",
                        color: .statusClean,
                        label: "\(done) done"
                    )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(Color.surfaceBase)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderSubtle).frame(height: 1)
        }
    }

    private func statusItem(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(color)
            Text(label)
                .font(.uiCaption)
                .foregroundStyle(Color.textSecondary)
        }
    }
}
