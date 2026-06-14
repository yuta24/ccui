import Combine
import SwiftUI

// MARK: - Global Agent Status (Titlebar accessory, right-aligned)

struct AgentStatusBar: View {
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    // staleness しきい値の境界を跨いだタイミングでも再評価されるよう、
    // 60 秒ごとに body を再評価するためのトリガ。
    @State private var staleTick: Int = 0

    private let staleTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        content
            .onReceive(staleTimer) { _ in
                staleTick &+= 1
            }
    }

    @ViewBuilder
    private var content: some View {
        let active = claudeEventStore.activeAgentCount
        let done = claudeEventStore.doneAgentCount
        let attention = claudeEventStore.attentionAgentCount
        let hasStatus = !claudeEventStore.sessions.isEmpty && (active > 0 || done > 0 || attention > 0)
        let canClear = attention > 0 || done > 0

        HStack(spacing: 8) {
            Spacer()
            if let loadError = claudeEventStore.loadError {
                statusItem(icon: "exclamationmark.triangle.fill", color: .diffDeletion, label: loadError)
            } else if hasStatus {
                let counters = HStack(spacing: 8) {
                    if active > 0 {
                        statusItem(icon: "hammer", color: .statusRenamed, label: "\(active)")
                    }
                    if attention > 0 {
                        statusItem(icon: "bell.fill", color: .accent, label: "\(attention)")
                    }
                    if done > 0 {
                        statusItem(icon: "checkmark.circle.fill", color: .statusClean, label: "\(done)")
                    }
                }
                if canClear {
                    Button {
                        claudeEventStore.acknowledgeAll()
                    } label: {
                        counters.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Mark all as read")
                } else {
                    counters
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

// MARK: - Content Controls (Titlebar accessory, trailing)

struct ContentControlsBar: View {
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(DetailUIState.self) private var detailUIState

    var body: some View {
        Group {
            if navigationStore.selectedWorktree != nil {
                GlassEffectContainer(spacing: PanelMetrics.contentControlSpacing) {
                    HStack(spacing: PanelMetrics.contentControlSpacing) {
                        if detailUIState.contentMode == .agent {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    detailUIState.agentLayoutMode = detailUIState.agentLayoutMode == .full ? .split : .full
                                }
                            } label: {
                                Image(systemName: detailUIState.agentLayoutMode == .split ? "rectangle.split.1x2.fill" : "rectangle.split.1x2")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(detailUIState.agentLayoutMode == .split ? Color.accent : Color.primary)
                                    .frame(width: PanelMetrics.contentControlButtonSize, height: PanelMetrics.contentControlButtonSize)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
                            .help("Toggle WebView Split (⌘U)")
                        }

                        Button {
                            detailUIState.isRightPanelVisible.toggle()
                        } label: {
                            Image(systemName: "sidebar.trailing")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(detailUIState.isRightPanelVisible ? Color.accent : Color.primary)
                                .frame(width: PanelMetrics.contentControlButtonSize, height: PanelMetrics.contentControlButtonSize)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
                        .help("Inspector (⌘I)")

                        Button {
                            detailUIState.isConfigurationSheetPresented.toggle()
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(detailUIState.isConfigurationSheetPresented ? Color.accent : Color.primary)
                                .frame(width: PanelMetrics.contentControlButtonSize, height: PanelMetrics.contentControlButtonSize)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
                        .help("Configuration")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, PanelMetrics.windowEdgeInset + 10)
        .frame(height: PanelMetrics.titleBarHeight)
    }
}
