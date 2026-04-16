import SwiftUI

@MainActor
final class RootContainerViewController: NSViewController {
    private let stores: StoreContainer
    private var keyMonitor: Any?

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

    override func viewDidAppear() {
        super.viewDidAppear()
        installKeyMonitor()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Keyboard Shortcuts

    private func installKeyMonitor() {
        if let existing = keyMonitor {
            NSEvent.removeMonitor(existing)
            keyMonitor = nil
        }

        let detailUIState = stores.detailUIState
        let quickOpenStore = stores.quickOpenStore
        let searchStore = stores.searchStore
        let coordinator = stores.appCoordinator
        let sessionComparisonStore = stores.sessionComparisonStore

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Cmd+Shift+E → toggle Agent/Files mode
            if chars == "e" && mods.contains(.command) && mods.contains(.shift) {
                guard coordinator.selectedWorktree != nil else { return event }
                detailUIState.contentMode = detailUIState.contentMode == .agent ? .files : .agent
                return nil
            }

            // Cmd+I → toggle Right Panel (Agent mode only)
            if chars == "i" && mods.contains(.command) && !mods.contains(.shift) {
                guard coordinator.selectedWorktree != nil else { return event }
                guard detailUIState.contentMode == .agent else { return event }
                detailUIState.isRightPanelVisible.toggle()
                return nil
            }

            // Cmd+Shift+F → content search (switch to Files mode) — check before Cmd+F
            if chars == "f" && mods.contains(.command) && mods.contains(.shift) {
                guard coordinator.selectedWorktree != nil else { return event }
                quickOpenStore.close()
                detailUIState.contentMode = .files
                searchStore.activate(mode: .content)
                return nil
            }

            // Cmd+F → file search (switch to Files mode)
            if chars == "f" && mods.contains(.command) && !mods.contains(.shift) {
                guard coordinator.selectedWorktree != nil else { return event }
                quickOpenStore.close()
                detailUIState.contentMode = .files
                searchStore.activate(mode: .files)
                return nil
            }

            // Cmd+P → quick open
            if chars == "p" && mods.contains(.command) {
                guard coordinator.selectedWorktree != nil else { return event }
                if !quickOpenStore.isVisible {
                    searchStore.deactivate()
                    quickOpenStore.open()
                }
                return nil
            }

            // Esc
            if event.keyCode == 53 {
                if sessionComparisonStore.isVisible {
                    sessionComparisonStore.close()
                    return nil
                }
                if quickOpenStore.isVisible {
                    quickOpenStore.close()
                    return nil
                }
                if searchStore.isActive {
                    searchStore.deactivate()
                    return nil
                }
            }

            return event
        }
    }
}
