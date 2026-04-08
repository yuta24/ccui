import SwiftUI

struct ContentView: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(TerminalSessionStore.self) private var terminalSessionStore
    @State private var selectedRepositoryID: Repository.ID?
    @State private var fileTreeStore: FileTreeStore?

    private var selectedRepository: Repository? {
        store.repositories.first { $0.id == selectedRepositoryID }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Repository picker
                HStack {
                    Picker(selection: $selectedRepositoryID) {
                        Text("Select a repository")
                            .tag(Repository.ID?.none)
                        Divider()
                        ForEach(store.repositories) { repo in
                            Text(repo.name)
                                .tag(Repository.ID?.some(repo.id))
                        }
                    } label: {
                        EmptyView()
                    }
                    .labelsHidden()

                    Button {
                        addRepository()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Add Repository")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                // File tree
                if let fileTreeStore {
                    FileTreeView(store: fileTreeStore)
                } else {
                    Spacer()
                    Text("Select a repository")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
        } detail: {
            if let repo = selectedRepository {
                DetailView(repository: repo, fileTreeStore: fileTreeStore)
            } else {
                Text("Select a repository")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
        .onChange(of: selectedRepositoryID) {
            if let repo = selectedRepository {
                fileTreeStore = FileTreeStore(rootPath: repo.path)
            } else {
                fileTreeStore = nil
            }
        }
        .onChange(of: store.repositories) {
            let validIDs = Set(store.repositories.map(\.id))
            terminalSessionStore.removeExcept(ids: validIDs)
            if let selectedRepositoryID, !validIDs.contains(selectedRepositoryID) {
                self.selectedRepositoryID = nil
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
