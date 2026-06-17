import Combine
import Sparkle
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var stores: AppDependencies?
    var mainWindowController: MainWindowController?
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        let deps = AppDependencies()
        stores = deps
        let controller = MainWindowController(stores: deps)
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
            AppSettingsView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    appDelegate.updaterController.checkForUpdates(nil)
                }
            }
            CommandGroup(after: .help) {
                Button("問題を報告…") {
                    IssueReporter.report()
                }
            }
        }
    }
}
