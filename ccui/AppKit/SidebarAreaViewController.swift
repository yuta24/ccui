import SwiftUI

@MainActor
final class SidebarAreaViewController: NSViewController {
    private let stores: StoreContainer

    init(stores: StoreContainer) {
        self.stores = stores
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let sidebarView = stores.injectEnvironment(into: SidebarContainerView())
            .preferredColorScheme(.dark)
        let sidebarVC = NSHostingController(rootView: sidebarView)
        sidebarVC.safeAreaRegions = []
        addChild(sidebarVC)

        view = sidebarVC.view
    }
}
