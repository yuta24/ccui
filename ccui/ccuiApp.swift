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
        }
        .defaultSize(width: 1200, height: 800)
    }
}
