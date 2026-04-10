import SwiftUI

@main
struct ccuiApp: App {
    @State private var repositoryStore = RepositoryStore(
        persistence: JSONFileRepositoryPersistence()
    )
    @State private var terminalSessionStore = TerminalSessionStore()
    @State private var claudeEventStore = ClaudeEventStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(repositoryStore)
                .environment(terminalSessionStore)
                .environment(claudeEventStore)
                .preferredColorScheme(.dark)
                .task { claudeEventStore.start() }
        }
        .defaultSize(width: 1280, height: 860)
        .windowStyle(.hiddenTitleBar)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                claudeEventStore.stop()
            }
        }
    }
}
