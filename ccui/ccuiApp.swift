import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var stores: StoreContainer!
    var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        stores = StoreContainer()
        let controller = MainWindowController(stores: stores)
        controller.showWindow(nil)
        mainWindowController = controller
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        stores?.shutdown()
    }
}

@main
struct ccuiApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Settings {
            if let stores = appDelegate.stores {
                AppSettingsView()
                    .environment(stores.appSettingsStore)
            }
        }
    }
}
