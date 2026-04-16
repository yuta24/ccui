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
        window.isRestorable = false
        window.minSize = NSSize(width: 900, height: 600)
        window.center()

        super.init(window: window)

        let rootVC = RootContainerViewController(stores: stores)
        window.contentViewController = rootVC

        stores.start()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
