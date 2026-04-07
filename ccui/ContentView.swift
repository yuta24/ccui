import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @State private var selectedRepositoryID: Repository.ID?

    private var selectedRepository: Repository? {
        store.repositories.first { $0.id == selectedRepositoryID }
    }

    var body: some View {
        NavigationSplitView {
            List(store.repositories, selection: $selectedRepositoryID) { repo in
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
                .contextMenu {
                    Button(role: .destructive) {
                        if selectedRepositoryID == repo.id {
                            selectedRepositoryID = nil
                        }
                        store.remove(repo)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addRepository()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add Repository")
                }
            }
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

    private func addRepository() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Repository"
        panel.message = "Select a folder to add as a repository"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.addRepository(at: url)
    }
}
