import AppKit

final class MainWindowController: NSWindowController {
    private let splitViewController = NSSplitViewController()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ccui"
        window.center()
        window.setFrameAutosaveName("MainWindow")

        self.init(window: window)
        setupSplitView()
    }

    private func setupSplitView() {
        let sidebarItem = NSSplitViewItem(
            sidebarWithViewController: SidebarViewController()
        )
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 350

        let contentItem = NSSplitViewItem(
            viewController: ContentViewController()
        )
        contentItem.minimumThickness = 600

        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(contentItem)

        window?.contentViewController = splitViewController
    }
}
