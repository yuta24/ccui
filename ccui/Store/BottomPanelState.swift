import Foundation

@Observable
@MainActor
final class BottomPanelState {
    private var expandedPaths: Set<String> = []

    func isExpanded(for path: String?) -> Bool {
        guard let path else { return false }
        return expandedPaths.contains(path)
    }

    func setExpanded(_ expanded: Bool, for path: String) {
        if expanded {
            expandedPaths.insert(path)
        } else {
            expandedPaths.remove(path)
        }
    }

    func toggle(for path: String) {
        setExpanded(!expandedPaths.contains(path), for: path)
    }

    func removeAll(for path: String) {
        expandedPaths.remove(path)
    }

    func removeExcept(paths: Set<String>) {
        expandedPaths = expandedPaths.intersection(paths)
    }
}
