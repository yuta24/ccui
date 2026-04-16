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

        let sidebarView = stores.injectEnvironment(into: SidebarContainerView())
        let sidebarVC = NSHostingController(rootView: sidebarView)
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.canCollapse = true
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 400
        addSplitViewItem(sidebarItem)

        let detailVC = DetailPaneViewController(stores: stores)
        let detailItem = NSSplitViewItem(viewController: detailVC)
        detailItem.minimumThickness = 400
        addSplitViewItem(detailItem)
    }
}
