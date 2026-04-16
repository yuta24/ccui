import SwiftUI

@MainActor
final class RootContainerViewController: NSViewController {
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

        // Dashboard bar (top, spans full width including sidebar)
        let dashboardView = stores.injectEnvironment(into: AgentDashboardBar())
            .preferredColorScheme(.dark)
        let dashboardVC = NSHostingController(rootView: dashboardView)
        addChild(dashboardVC)
        dashboardVC.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dashboardVC.view)

        // Split view (below dashboard bar)
        let splitVC = MainSplitViewController(stores: stores)
        addChild(splitVC)
        splitVC.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(splitVC.view)

        // Title bar spacer (traffic lights area)
        let titleBarHeight: CGFloat = 28

        NSLayoutConstraint.activate([
            dashboardVC.view.topAnchor.constraint(equalTo: container.topAnchor, constant: titleBarHeight),
            dashboardVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dashboardVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dashboardVC.view.heightAnchor.constraint(equalToConstant: 36),

            splitVC.view.topAnchor.constraint(equalTo: dashboardVC.view.bottomAnchor),
            splitVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            splitVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            splitVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        view = container
    }
}
