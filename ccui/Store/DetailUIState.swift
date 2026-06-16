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
    case eval = "Eval"

    var icon: String {
        switch self {
        case .timeline: "chart.bar.xaxis"
        case .changes: "arrow.left.arrow.right"
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
    var webViewTabsStore = WebViewTabsStore()

    func resetForWorktreeChange() {
        contentMode = .agent
        agentLayoutMode = .full
        isRightPanelVisible = false
        rightPanelTab = .timeline
        isConfigurationSheetPresented = false
        sessionEvaluationStore.close()
        webViewTabsStore.reset()
    }
}
