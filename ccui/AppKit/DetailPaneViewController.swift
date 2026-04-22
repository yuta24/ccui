import SwiftUI

@MainActor
final class DetailPaneViewController: NSViewController, NSSplitViewDelegate {
    private let stores: StoreContainer
    private var bottomPanelState: BottomPanelState { stores.bottomPanelState }
    private var collapsedHeight: CGFloat { BottomTerminalViewController.collapsedHeight }
    private let defaultExpandedHeight: CGFloat = 220
    private var isUpdatingSplitFromState = false
    private var isObserving = false

    private var currentWorktreePath: String? {
        stores.appCoordinator.selectedWorktree?.path
    }

    private var isExpandedForCurrent: Bool {
        bottomPanelState.isExpanded(for: currentWorktreePath)
    }

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
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = NSColor.surfaceWindowColor.cgColor
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

    override func viewDidAppear() {
        super.viewDidAppear()
        if !isObserving {
            isObserving = true
            observeBottomPanelState()
        }
    }

    // MARK: - State Observation

    private func observeBottomPanelState() {
        withObservationTracking {
            _ = isExpandedForCurrent
            _ = stores.appCoordinator.selectedWorktree
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
        if isExpandedForCurrent {
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

    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        guard children.count == 2 else {
            splitView.adjustSubviews()
            return
        }
        let topView = children[0].view
        let bottomView = children[1].view
        let dividerThickness = splitView.dividerThickness
        let newHeight = splitView.frame.height
        let newWidth = splitView.frame.width

        // Preserve current bottom height, enforcing minimum
        var bottomHeight = bottomView.frame.height
        if bottomHeight < collapsedHeight {
            bottomHeight = collapsedHeight
        }
        let topHeight = newHeight - bottomHeight - dividerThickness

        // NSSplitView is flipped: y=0 is top
        topView.frame = NSRect(x: 0, y: 0, width: newWidth, height: topHeight)
        bottomView.frame = NSRect(x: 0, y: topHeight + dividerThickness, width: newWidth, height: bottomHeight)
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard !isUpdatingSplitFromState else { return }
        guard children.count > 1 else { return }
        guard let path = currentWorktreePath else { return }
        let bottomHeight = children[1].view.frame.height
        let expanded = bottomHeight > collapsedHeight + 10
        if bottomPanelState.isExpanded(for: path) != expanded {
            isUpdatingSplitFromState = true
            bottomPanelState.setExpanded(expanded, for: path)
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
