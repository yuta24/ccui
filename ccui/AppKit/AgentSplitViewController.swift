import SwiftUI

/// Hosts `AgentContentView` and `WebViewPanelView` as panes of an
/// `NSSplitViewController`, so toggling the WebView panel can be animated via
/// `NSSplitViewItem.isCollapsed`. SwiftUI's `HSplitView` does not animate pane
/// insertion/removal, even within `withAnimation`.
@MainActor
final class AgentSplitViewController: NSSplitViewController {
    private let agentHostingController = NSHostingController(rootView: AnyView(EmptyView()))
    private let webViewHostingController = NSHostingController(rootView: AnyView(EmptyView()))
    private var webViewItem: NSSplitViewItem!
    private var worktree: Worktree
    private let bottomPanelState: BottomPanelState

    init(
        worktree: Worktree,
        isSplit: Bool,
        webViewTabsStore: WebViewTabsStore,
        terminalSessionStore: TerminalSessionStore,
        bottomPanelState: BottomPanelState
    ) {
        self.worktree = worktree
        self.bottomPanelState = bottomPanelState
        super.init(nibName: nil, bundle: nil)

        splitView.isVertical = true
        splitView.dividerStyle = .thin

        agentHostingController.safeAreaRegions = []
        agentHostingController.sizingOptions = []
        agentHostingController.view.wantsLayer = true
        agentHostingController.view.layer?.backgroundColor = NSColor.surfacePrimaryColor.resolvedRGB.cgColor
        let agentItem = NSSplitViewItem(viewController: agentHostingController)
        agentItem.minimumThickness = 300
        addSplitViewItem(agentItem)

        webViewHostingController.safeAreaRegions = []
        webViewHostingController.sizingOptions = []
        webViewItem = NSSplitViewItem(viewController: webViewHostingController)
        webViewItem.minimumThickness = 300
        webViewItem.canCollapse = false
        webViewItem.isCollapsed = !isSplit
        addSplitViewItem(webViewItem)

        applyContent(
            webViewTabsStore: webViewTabsStore,
            terminalSessionStore: terminalSessionStore,
            bottomPanelState: bottomPanelState
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        worktree: Worktree,
        isSplit: Bool,
        webViewTabsStore: WebViewTabsStore,
        terminalSessionStore: TerminalSessionStore,
        bottomPanelState: BottomPanelState
    ) {
        if isSplit == webViewItem.isCollapsed {
            animateSplit(isSplit)
        }

        if self.worktree != worktree {
            self.worktree = worktree
            applyContent(
                webViewTabsStore: webViewTabsStore,
                terminalSessionStore: terminalSessionStore,
                bottomPanelState: bottomPanelState
            )
        }
    }

    private func applyContent(
        webViewTabsStore: WebViewTabsStore,
        terminalSessionStore: TerminalSessionStore,
        bottomPanelState: BottomPanelState
    ) {
        agentHostingController.rootView = AnyView(
            AgentContentView(worktree: worktree)
                .environment(terminalSessionStore)
                .environment(bottomPanelState)
        )
        webViewHostingController.rootView = AnyView(
            WebViewPanelView(worktree: worktree, tabsStore: webViewTabsStore)
                .environment(terminalSessionStore)
        )
    }

    /// Animates the WebView pane in/out via `WindowLayoutCoordinator`, which
    /// freezes the agent terminal's size for the duration (`bottomPanelState`)
    /// to avoid repeated SIGWINCH-triggered redraws while the pane resizes.
    private func animateSplit(_ isSplit: Bool) {
        WindowLayoutCoordinator.animate(bottomPanelState: bottomPanelState) {
            self.webViewItem.animator().isCollapsed = !isSplit
            self.splitView.layoutSubtreeIfNeeded()
        }
    }
}
