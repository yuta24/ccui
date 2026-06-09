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
        // NSVisualEffectView provides the characteristic macOS sidebar material
        let effectView = NSVisualEffectView()
        effectView.material = .sidebar
        effectView.blendingMode = .behindWindow
        effectView.state = .active

        let sidebarView = stores.injectEnvironment(into: SidebarContainerView())
        let sidebarVC = NSHostingController(rootView: sidebarView)
        sidebarVC.safeAreaRegions = []
        // Let the NSVisualEffectView material show through
        sidebarVC.view.wantsLayer = true
        sidebarVC.view.layer?.backgroundColor = NSColor.clear.cgColor
        addChild(sidebarVC)

        sidebarVC.view.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(sidebarVC.view)

        NSLayoutConstraint.activate([
            sidebarVC.view.topAnchor.constraint(equalTo: effectView.topAnchor),
            sidebarVC.view.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            sidebarVC.view.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            sidebarVC.view.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
        ])

        view = effectView
    }
}
