import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct ccuiApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @State private var repositoryStore = RepositoryStore(
        persistence: JSONFileRepositoryPersistence()
    )
    @State private var terminalSessionStore = TerminalSessionStore()
    @State private var claudeEventStore = ClaudeEventStore()
    @State private var worktreeSessionStore = WorktreeSessionStore()
    @State private var shellSessionStore = ShellSessionStore()
    @State private var appCoordinator = AppCoordinator()

    var body: some Scene {
        Window("ccui", id: "main") {
            ContentView()
                .environment(repositoryStore)
                .environment(terminalSessionStore)
                .environment(claudeEventStore)
                .environment(worktreeSessionStore)
                .environment(shellSessionStore)
                .environment(appCoordinator)
                .preferredColorScheme(.dark)
                .task {
                    claudeEventStore.start()
                    terminalSessionStore.startResolvingClaudePath()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.willTerminateNotification
                    )
                ) { _ in
                    shutdown()
                }
        }
        .defaultSize(width: 1280, height: 860)
        .windowStyle(.hiddenTitleBar)
    }

    private func shutdown() {
        terminalSessionStore.terminateAll()
        shellSessionStore.terminateAll()
        claudeEventStore.stop()
        worktreeSessionStore.save()
    }
}
