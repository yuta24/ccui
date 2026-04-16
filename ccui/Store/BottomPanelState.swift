import Foundation

@Observable
@MainActor
final class BottomPanelState {
    var isExpanded = false

    func toggle() {
        isExpanded.toggle()
    }

    func collapse() {
        isExpanded = false
    }
}
