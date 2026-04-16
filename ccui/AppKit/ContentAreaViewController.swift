import SwiftUI

@MainActor
final class ContentAreaViewController: NSSplitViewController {
    private let stores: StoreContainer
    private var isUpdatingFromState = false
    private var isObserving = false

    private var rightPanelItem: NSSplitViewItem!

    init(stores: StoreContainer) {
        self.stores = stores
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = NSColor.surfaceWindowColor.cgColor

        // Left: ContentView (dashboard bar + main content + overlays)
        let leftView = stores.injectEnvironment(into: ContentView())
            .preferredColorScheme(.dark)
        let leftVC = NSHostingController(rootView: leftView)
        leftVC.safeAreaRegions = []
        let leftItem = NSSplitViewItem(viewController: leftVC)
        leftItem.minimumThickness = 300
        addSplitViewItem(leftItem)

        // Right: RightPanelView
        let rightView = stores.injectEnvironment(into: RightPanelContainerView())
            .preferredColorScheme(.dark)
        let rightVC = NSHostingController(rootView: rightView)
        rightVC.safeAreaRegions = []
        rightPanelItem = NSSplitViewItem(viewController: rightVC)
        rightPanelItem.minimumThickness = 220
        rightPanelItem.canCollapse = true
        rightPanelItem.isCollapsed = true
        addSplitViewItem(rightPanelItem)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if !isObserving {
            isObserving = true
            observeRightPanelState()
        }
    }

    // MARK: - State Observation

    private func observeRightPanelState() {
        withObservationTracking {
            _ = stores.detailUIState.isRightPanelVisible
            _ = stores.detailUIState.contentMode
        } onChange: {
            Task { @MainActor [weak self] in
                self?.handleRightPanelStateChanged()
                self?.observeRightPanelState()
            }
        }
    }

    private func handleRightPanelStateChanged() {
        let shouldShow = stores.detailUIState.isRightPanelVisible
            && stores.detailUIState.contentMode == .agent
        if shouldShow && rightPanelItem.isCollapsed {
            expandRightPanel()
        } else if !shouldShow && !rightPanelItem.isCollapsed {
            collapseRightPanel()
        }
    }

    private func collapseRightPanel() {
        isUpdatingFromState = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            rightPanelItem.isCollapsed = true
        }, completionHandler: {
            Task { @MainActor [weak self] in
                self?.isUpdatingFromState = false
            }
        })
    }

    private func expandRightPanel() {
        isUpdatingFromState = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            rightPanelItem.isCollapsed = false
        }, completionHandler: {
            Task { @MainActor [weak self] in
                self?.isUpdatingFromState = false
            }
        })
    }

    // MARK: - NSSplitViewDelegate

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        guard !isUpdatingFromState else { return }
        let collapsed = rightPanelItem.isCollapsed
        let visible = stores.detailUIState.isRightPanelVisible
        if visible == collapsed {
            isUpdatingFromState = true
            stores.detailUIState.isRightPanelVisible = !collapsed
            isUpdatingFromState = false
        }
    }
}
