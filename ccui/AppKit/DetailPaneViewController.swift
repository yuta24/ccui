import SwiftUI

@MainActor
final class DetailPaneViewController: NSViewController, NSSplitViewDelegate {
    private let stores: StoreContainer
    private var bottomPanelState: BottomPanelState { stores.bottomPanelState }
    private let collapsedHeight: CGFloat = 32
    private let defaultExpandedHeight: CGFloat = 220
    private var isUpdatingSplitFromState = false
    private var didInitialLayout = false

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
        splitView.isVertical = false
        splitView.dividerStyle = .thin
        splitView.delegate = self

        // Top: ContentAreaViewController (content + right panel split)
        let topVC = ContentAreaViewController(stores: stores)
        addChild(topVC)

        // Bottom: BottomTerminalViewController (AppKit-managed terminal)
        let bottomVC = BottomTerminalViewController(stores: stores, bottomPanelState: stores.bottomPanelState)
        addChild(bottomVC)

        splitView.addArrangedSubview(topVC.view)
        splitView.addArrangedSubview(bottomVC.view)

        view = splitView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard !didInitialLayout else { return }
        didInitialLayout = true
        guard let splitView = view as? NSSplitView else { return }
        let targetY = splitView.frame.height - collapsedHeight
        splitView.setPosition(targetY, ofDividerAt: 0)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        observeBottomPanelState()
    }

    // MARK: - State Observation

    private func observeBottomPanelState() {
        withObservationTracking {
            _ = bottomPanelState.isExpanded
        } onChange: {
            Task { @MainActor [weak self] in
                self?.handleExpandedChanged()
                self?.observeBottomPanelState()
            }
        }
    }

    private func handleExpandedChanged() {
        guard let splitView = view as? NSSplitView else { return }
        let totalHeight = splitView.frame.height
        let targetPosition: CGFloat
        if bottomPanelState.isExpanded {
            targetPosition = totalHeight - defaultExpandedHeight
        } else {
            targetPosition = totalHeight - collapsedHeight
        }
        isUpdatingSplitFromState = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            splitView.setPosition(targetPosition, ofDividerAt: 0)
        }, completionHandler: {
            Task { @MainActor [weak self] in
                self?.isUpdatingSplitFromState = false
            }
        })
    }

    // MARK: - NSSplitViewDelegate

    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard !isUpdatingSplitFromState else { return }
        guard children.count > 1 else { return }
        let bottomHeight = children[1].view.frame.height
        let expanded = bottomHeight > collapsedHeight + 10
        if bottomPanelState.isExpanded != expanded {
            isUpdatingSplitFromState = true
            bottomPanelState.isExpanded = expanded
            isUpdatingSplitFromState = false
        }
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        120
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        splitView.frame.height - collapsedHeight
    }
}
