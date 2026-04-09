import SwiftUI

@main
struct ccuiApp: App {
    @State private var repositoryStore = RepositoryStore(
        persistence: JSONFileRepositoryPersistence()
    )
    @State private var terminalSessionStore = TerminalSessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(repositoryStore)
                .environment(terminalSessionStore)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1280, height: 860)
        .windowStyle(.hiddenTitleBar)
    }
}
