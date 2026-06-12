import Foundation

enum DetailContentMode {
    case agent
    case files
}

enum AgentLayoutMode {
    case full
    case split
}

enum RightPanelTab: String, CaseIterable {
    case timeline = "Timeline"
    case changes = "Changes"
    case stats = "Stats"
    case eval = "Eval"

    var icon: String {
        switch self {
        case .timeline: "chart.bar.xaxis"
        case .changes: "arrow.left.arrow.right"
        case .stats: "chart.bar"
        case .eval: "checkmark.seal"
        }
    }
}

@Observable
@MainActor
final class DetailUIState {
    var contentMode: DetailContentMode = .agent
    var agentLayoutMode: AgentLayoutMode = .full
    var isRightPanelVisible = false
    var rightPanelTab: RightPanelTab = .timeline
    var isConfigurationSheetPresented = false
    var sessionEvaluationStore = SessionEvaluationStore()
    var sessionAnalyticsStore: SessionAnalyticsStore
    var webViewStore = WebViewStore()

    init(persistence: ClaudeEventPersistence? = nil) {
        if let persistence {
            self.sessionAnalyticsStore = SessionAnalyticsStore(persistence: persistence)
        } else {
            self.sessionAnalyticsStore = SessionAnalyticsStore()
        }
    }

    func resetForWorktreeChange() {
        contentMode = .agent
        agentLayoutMode = .full
        isRightPanelVisible = false
        rightPanelTab = .timeline
        isConfigurationSheetPresented = false
        sessionEvaluationStore.close()
        webViewStore.reset()
    }
}
