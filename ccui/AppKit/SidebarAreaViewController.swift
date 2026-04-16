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
        let container = NSView()
        container.wantsLayer = true

        // Status bar (full width, above the floating panel)
        let statusBarView = stores.injectEnvironment(into: AgentStatusBar())
            .preferredColorScheme(.dark)
        let statusBarHosting = NSHostingView(rootView: statusBarView)
        statusBarHosting.translatesAutoresizingMaskIntoConstraints = false

        // Sidebar content (floating panel)
        let sidebarView = stores.injectEnvironment(into: SidebarContainerView())
            .preferredColorScheme(.dark)
        let sidebarVC = NSHostingController(rootView: sidebarView)
        sidebarVC.safeAreaRegions = []
        addChild(sidebarVC)
        let sidebarHosting = sidebarVC.view
        sidebarHosting.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(statusBarHosting)
        container.addSubview(sidebarHosting)

        NSLayoutConstraint.activate([
            statusBarHosting.topAnchor.constraint(equalTo: container.topAnchor),
            statusBarHosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            statusBarHosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            statusBarHosting.heightAnchor.constraint(equalToConstant: PanelMetrics.toolbarHeight),

            sidebarHosting.topAnchor.constraint(equalTo: statusBarHosting.bottomAnchor),
            sidebarHosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sidebarHosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sidebarHosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        view = container
    }
}
