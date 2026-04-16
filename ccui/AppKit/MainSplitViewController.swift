import SwiftUI

@MainActor
final class MainSplitViewController: NSSplitViewController {
    private let stores: StoreContainer

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

        splitView.dividerStyle = .thin
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = NSColor.surfaceWindowColor.cgColor

        let sidebarVC = SidebarAreaViewController(stores: stores)
        let sidebarItem = NSSplitViewItem(viewController: sidebarVC)
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 400
        addSplitViewItem(sidebarItem)

        let detailVC = DetailPaneViewController(stores: stores)
        let detailItem = NSSplitViewItem(viewController: detailVC)
        detailItem.minimumThickness = 400
        addSplitViewItem(detailItem)
    }
}
