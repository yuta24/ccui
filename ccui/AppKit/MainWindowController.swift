import SwiftUI

@MainActor
final class MainWindowController: NSWindowController {
    let stores: AppDependencies

    init(stores: AppDependencies) {
        self.stores = stores

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isRestorable = false
        window.minSize = NSSize(width: 900, height: 600)
        window.center()
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        let toolbar = NSToolbar()
        toolbar.allowsUserCustomization = false
        toolbar.allowsDisplayModeCustomization = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        super.init(window: window)

        let rootVC = RootContainerViewController(stores: stores)
        window.contentViewController = rootVC

        // Trailing accessory: global agent status counters
        let statusBarView = stores.injectEnvironment(into: AgentStatusBar())
        let statusHosting = NSHostingView(rootView: statusBarView)
        statusHosting.sizingOptions = .intrinsicContentSize
        let statusAccessoryVC = NSTitlebarAccessoryViewController()
        statusAccessoryVC.layoutAttribute = .trailing
        statusAccessoryVC.view = statusHosting
        window.addTitlebarAccessoryViewController(statusAccessoryVC)

        stores.start()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
