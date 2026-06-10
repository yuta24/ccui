import Foundation

@Observable
@MainActor
final class BottomPanelState {
    private var expandedPaths: Set<String> = []

    /// 分割ビューのリサイズアニメーション（ボトムパネルの開閉、エージェント
    /// スプリットのブラウザパネル開閉など）が進行中かどうか。
    /// アニメーション中はエージェントターミナルが何度もリサイズされ、
    /// SIGWINCH による全画面再描画が連発してカクつくのを防ぐため、
    /// AgentTerminalViewController 側でこの間サイズを固定する。
    /// 複数のアニメーションが同時に進行しうるため進行数をカウントし、
    /// すべて完了してから固定を解除する。
    private var activeResizeAnimationCount = 0

    var isAnimatingResize: Bool { activeResizeAnimationCount > 0 }

    /// リサイズアニメーションの開始を記録する。`endResizeAnimation()` と必ず対で呼ぶこと。
    func beginResizeAnimation() {
        activeResizeAnimationCount += 1
    }

    /// リサイズアニメーションの終了を記録する。
    func endResizeAnimation() {
        activeResizeAnimationCount = max(0, activeResizeAnimationCount - 1)
    }

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
