import Foundation

@Observable
@MainActor
final class BottomPanelState {
    private var expandedPaths: Set<String> = []

    /// ボトムパネルの開閉アニメーション中は true。
    /// アニメーション中はエージェントターミナルが何度もリサイズされ、
    /// SIGWINCH による全画面再描画が連発してカクつくのを防ぐため、
    /// AgentTerminalViewController 側でこの間サイズを固定する。
    var isAnimatingResize: Bool = false

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
