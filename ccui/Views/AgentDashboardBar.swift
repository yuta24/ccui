import SwiftUI

// MARK: - Global Agent Status (Titlebar accessory, right-aligned)

struct AgentStatusBar: View {
    @Environment(ClaudeEventStore.self) private var claudeEventStore

    var body: some View {
        let active = claudeEventStore.activeAgentCount
        let done = claudeEventStore.doneAgentCount
        let notified = claudeEventStore.notifiedAgentCount
        let hasStatus = !claudeEventStore.sessions.isEmpty && (active > 0 || done > 0 || notified > 0)

        HStack(spacing: 8) {
            Spacer()
            if let loadError = claudeEventStore.loadError {
                statusItem(icon: "exclamationmark.triangle.fill", color: .diffDeletion, label: loadError)
            } else if hasStatus {
                if active > 0 {
                    statusItem(icon: "hammer", color: .statusRenamed, label: "\(active)")
                }
                if notified > 0 {
                    statusItem(icon: "bell.fill", color: .accent, label: "\(notified)")
                }
                if done > 0 {
                    statusItem(icon: "checkmark.circle.fill", color: .statusClean, label: "\(done)")
                }
            }
        }
        .padding(.trailing, PanelMetrics.windowEdgeInset + 10)
        .frame(height: PanelMetrics.titleBarHeight)
    }

    private func statusItem(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(color)
            Text(label)
                .font(.uiCaptionMono)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: - Content Toolbar (Content panel top)

struct ContentToolbar: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(DetailUIState.self) private var detailUIState

    var body: some View {
        HStack(spacing: 12) {
            // Branch name (left)
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
            if coordinator.selectedWorktree != nil {
                HStack(spacing: 4) {
                    Button {
                        detailUIState.isRightPanelVisible.toggle()
                    } label: {
                        Image(systemName: "sidebar.trailing")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(detailUIState.isRightPanelVisible ? Color.accent : Color.textSecondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.hoverScale)
                    .help("Inspector (⌘I)")

                    Button {
                        detailUIState.showingConfiguration.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(detailUIState.showingConfiguration ? Color.accent : Color.textSecondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.hoverScale)
                    .help("Configuration")
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: PanelMetrics.toolbarHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderSubtle).frame(height: 1)
        }
    }
}
