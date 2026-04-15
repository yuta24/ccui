import SwiftUI

struct AgentDashboardBar: View {
    @Binding var showingConfiguration: Bool
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        let active = claudeEventStore.activeAgentCount
        let done = claudeEventStore.doneAgentCount
        let notified = claudeEventStore.notifiedAgentCount
        let hasStatus = !claudeEventStore.sessions.isEmpty && (active > 0 || done > 0 || notified > 0)

        HStack(spacing: 12) {
            // Agent status (left)
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

            // Session title (center-right)
            if let worktree = coordinator.selectedWorktree {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 9, weight: .medium))
                    Text(worktree.displayName)
                        .font(.uiCaption)
                }
                .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            // Actions (right)
            HStack(spacing: 4) {
                if coordinator.selectedWorktree != nil {
                    Button {
                        showingConfiguration.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(showingConfiguration ? Color.accent : Color.textSecondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Configuration")
                }
            }
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
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
