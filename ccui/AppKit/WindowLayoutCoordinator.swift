import AppKit

/// NSSplitViewItem の collapse/expand などレイアウト変更を `NSAnimationContext` で
/// アニメーションさせる処理を共通化する。`bottomPanelState` を渡すと
/// `beginResizeAnimation()`/`endResizeAnimation()` で囲み、アニメーション中は
/// エージェントターミナルのサイズを固定して SIGWINCH による再描画の連発を防ぐ。
@MainActor
enum WindowLayoutCoordinator {
    static let animationDuration: TimeInterval = 0.2

    static func animate(
        bottomPanelState: BottomPanelState? = nil,
        changes: @escaping () -> Void,
        completion: (() -> Void)? = nil
    ) {
        bottomPanelState?.beginResizeAnimation()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animationDuration
            context.allowsImplicitAnimation = true
            changes()
        }, completionHandler: {
            Task { @MainActor in
                completion?()
                bottomPanelState?.endResizeAnimation()
            }
        })
    }
}
