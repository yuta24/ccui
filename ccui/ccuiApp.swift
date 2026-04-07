import SwiftUI

@main
struct ccuiApp: App {
    @State private var repositoryStore = RepositoryStore(
        persistence: JSONFileRepositoryPersistence()
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(repositoryStore)
        }
        .defaultSize(width: 1200, height: 800)
    }
}
