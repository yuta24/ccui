import SwiftUI

@main
struct ccuiApp: App {
    @State private var repositoryStore = RepositoryStore(
        persistence: JSONFileRepositoryPersistence()
    )
    @State private var terminalSessionStore = TerminalSessionStore()
    @State private var claudeEventStore = ClaudeEventStore()
    @State private var appCoordinator = AppCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(repositoryStore)
                .environment(terminalSessionStore)
                .environment(claudeEventStore)
                .environment(appCoordinator)
                .preferredColorScheme(.dark)
                .task { claudeEventStore.start() }
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                claudeEventStore.stop()
            }
        }
    }

    private func shutdown() {
        terminalSessionStore.terminateAll()
        claudeEventStore.stop()
    }
}
