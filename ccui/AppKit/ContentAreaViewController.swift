import SwiftUI

// MARK: - Inner split view controller with resize callback

@MainActor
final class ContentSplitViewController: NSSplitViewController {
    var onResizeSubviews: (() -> Void)?

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        onResizeSubviews?()
    }
}

// MARK: - Content Area (toolbar + left/right split)

@MainActor
final class ContentAreaViewController: NSViewController {
    private let stores: StoreContainer
    private var isUpdatingFromState = false
    private var isObserving = false

    private var splitVC: ContentSplitViewController!
    private var rightPanelItem: NSSplitViewItem!

    init(stores: StoreContainer) {
        self.stores = stores
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true

        // Toolbar (full width, above the split)
        let toolbarView = stores.injectEnvironment(into: ContentToolbar())
            .preferredColorScheme(.dark)
        let toolbarHosting = NSHostingView(rootView: toolbarView)
        toolbarHosting.translatesAutoresizingMaskIntoConstraints = false

        // Split view controller
        splitVC = ContentSplitViewController()
        splitVC.splitView.isVertical = true
        splitVC.splitView.dividerStyle = .thin
        splitVC.splitView.wantsLayer = true
        splitVC.splitView.layer?.backgroundColor = NSColor.surfaceWindowColor.cgColor
        splitVC.onResizeSubviews = { [weak self] in
            self?.handleSplitViewResize()
        }

        // Left: ContentView (main content + overlays, no toolbar)
        let leftView = stores.injectEnvironment(into: ContentView())
            .preferredColorScheme(.dark)
        let leftVC = NSHostingController(rootView: leftView)
        leftVC.safeAreaRegions = []
        let leftItem = NSSplitViewItem(viewController: leftVC)
        leftItem.minimumThickness = 300
        splitVC.addSplitViewItem(leftItem)

        // Right: RightPanelView
        let rightView = stores.injectEnvironment(into: RightPanelContainerView())
            .preferredColorScheme(.dark)
        let rightVC = NSHostingController(rootView: rightView)
        rightVC.safeAreaRegions = []
        rightPanelItem = NSSplitViewItem(viewController: rightVC)
        rightPanelItem.minimumThickness = 220
        rightPanelItem.canCollapse = true
        rightPanelItem.isCollapsed = true
        splitVC.addSplitViewItem(rightPanelItem)

        addChild(splitVC)
        let splitViewContainer = splitVC.view
        splitViewContainer.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(toolbarHosting)
        container.addSubview(splitViewContainer)

        NSLayoutConstraint.activate([
            toolbarHosting.topAnchor.constraint(equalTo: container.topAnchor),
            toolbarHosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            toolbarHosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toolbarHosting.heightAnchor.constraint(equalToConstant: PanelMetrics.toolbarHeight),

            splitViewContainer.topAnchor.constraint(equalTo: toolbarHosting.bottomAnchor),
            splitViewContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            splitViewContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            splitViewContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        view = container
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

    // MARK: - Split View Resize Sync

    private func handleSplitViewResize() {
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
