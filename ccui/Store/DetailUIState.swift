import Foundation

enum DetailContentMode {
    case agent
    case files
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
    var isRightPanelVisible = false
    var rightPanelTab: RightPanelTab = .timeline
    var showingConfiguration = false
    var sessionEvaluationStore = SessionEvaluationStore()

    func resetForWorktreeChange() {
        contentMode = .agent
        isRightPanelVisible = false
        rightPanelTab = .timeline
        showingConfiguration = false
        sessionEvaluationStore.close()
    }
}
