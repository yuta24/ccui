import SwiftUI

struct ContentView: View {
    @State private var selectedRepositoryID: Repository.ID?

    private let repositories: [Repository] = [
        Repository(name: "ccui", path: "/Users/nova/ghq/github.com/yuta24/ccui"),
        Repository(name: "swift-project", path: "/tmp/swift-project"),
        Repository(name: "my-app", path: "/tmp/my-app"),
    ]

    private var selectedRepository: Repository? {
        repositories.first { $0.id == selectedRepositoryID }
    }

    var body: some View {
        NavigationSplitView {
            List(repositories, selection: $selectedRepositoryID) { repo in
                NavigationLink(value: repo.id) {
                    Label {
                        VStack(alignment: .leading) {
                            Text(repo.name)
                                .font(.body)
                            Text(repo.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } detail: {
            if let repo = selectedRepository {
                DetailView(repository: repo)
            } else {
                Text("Select a repository")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
