import Foundation

@Observable
@MainActor
final class BottomPanelStore {
    enum PanelTab {
        case diff
        case code
    }

    var isExpanded: Bool = false
    var panelHeight: CGFloat = 280
    var selectedTab: PanelTab = .code

    static let minHeight: CGFloat = 120
    static let maxHeightFraction: CGFloat = 0.75

    func toggle() {
        isExpanded.toggle()
    }

    func expand() {
        isExpanded = true
    }

    func collapse() {
        isExpanded = false
    }
}
