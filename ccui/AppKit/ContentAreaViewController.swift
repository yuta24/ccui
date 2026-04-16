import SwiftUI

@MainActor
final class ContentAreaViewController: NSViewController, NSSplitViewDelegate {
    private let stores: StoreContainer
    private var isUpdatingFromState = false
    private var rightPanelCollapsed = true
    private var didInitialLayout = false
    private var isObserving = false

    init(stores: StoreContainer) {
        self.stores = stores
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        // Left: ContentView (dashboard bar + main content + overlays)
        let leftView = stores.injectEnvironment(into: ContentView())
            .preferredColorScheme(.dark)
        let leftVC = NSHostingController(rootView: leftView)
        addChild(leftVC)

        // Right: RightPanelView
        let rightView = stores.injectEnvironment(into: RightPanelContainerView())
            .preferredColorScheme(.dark)
        let rightVC = NSHostingController(rootView: rightView)
        addChild(rightVC)

        splitView.addArrangedSubview(leftVC.view)
        splitView.addArrangedSubview(rightVC.view)

        view = splitView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard let splitView = view as? NSSplitView else { return }
        if !didInitialLayout, splitView.frame.width > 0 {
            didInitialLayout = true
            splitView.setPosition(splitView.frame.width, ofDividerAt: 0)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if !isObserving {
            isObserving = true
            // Ensure right panel is collapsed on first appear
            if let splitView = view as? NSSplitView {
                splitView.setPosition(splitView.frame.width, ofDividerAt: 0)
            }
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
        if shouldShow && rightPanelCollapsed {
            expandRightPanel()
        } else if !shouldShow && !rightPanelCollapsed {
            collapseRightPanel()
        }
    }

    private func collapseRightPanel() {
        guard let splitView = view as? NSSplitView else { return }
        rightPanelCollapsed = true
        isUpdatingFromState = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            splitView.setPosition(splitView.frame.width, ofDividerAt: 0)
        }, completionHandler: {
            Task { @MainActor [weak self] in
                self?.isUpdatingFromState = false
            }
        })
    }

    private func expandRightPanel() {
        guard let splitView = view as? NSSplitView else { return }
        rightPanelCollapsed = false
        isUpdatingFromState = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            splitView.setPosition(splitView.frame.width - 280, ofDividerAt: 0)
        }, completionHandler: {
            Task { @MainActor [weak self] in
                self?.isUpdatingFromState = false
            }
        })
    }

    // MARK: - NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        300
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        splitView.frame.width - 220
    }

    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        guard children.count > 1 else { return false }
        return subview === children[1].view
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard !isUpdatingFromState, children.count > 1 else { return }
        let rightWidth = children[1].view.frame.width
        let collapsed = rightWidth < 10
        if rightPanelCollapsed != collapsed {
            rightPanelCollapsed = collapsed
            isUpdatingFromState = true
            if stores.detailUIState.isRightPanelVisible != !collapsed {
                stores.detailUIState.isRightPanelVisible = !collapsed
            }
            isUpdatingFromState = false
        }
    }
}
