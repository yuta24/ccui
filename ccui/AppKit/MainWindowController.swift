import SwiftUI

@MainActor
final class MainWindowController: NSWindowController {
    let stores: StoreContainer

    init(stores: StoreContainer) {
        self.stores = stores

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor.surfaceWindowColor
        window.isRestorable = false
        window.minSize = NSSize(width: 900, height: 600)
        window.center()

        super.init(window: window)

        let rootVC = RootContainerViewController(stores: stores)
        window.contentViewController = rootVC

        let statusBarView = stores.injectEnvironment(into: AgentStatusBar())
            .preferredColorScheme(.dark)
        let hosting = NSHostingView(rootView: statusBarView)
        hosting.frame = NSRect(x: 0, y: 0, width: 200, height: PanelMetrics.titleBarHeight)

        let accessoryVC = NSTitlebarAccessoryViewController()
        accessoryVC.layoutAttribute = .trailing
        accessoryVC.view = hosting
        window.addTitlebarAccessoryViewController(accessoryVC)

        stores.start()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
