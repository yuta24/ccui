import Foundation

@Observable
@MainActor
final class DiffStore {
    enum DiffMode: String, CaseIterable {
        case staged = "Staged"
        case unstaged = "Unstaged"
    }

    enum State {
        case idle
        case loading
        case loaded([DiffFileEntry])
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var selectedFileIndex: Int?
    var mode: DiffMode = .staged
    private var loadToken = UUID()

    func load(repositoryPath: String, mode newMode: DiffMode? = nil) async {
        if let newMode { mode = newMode }
        state = .loading
        selectedFileIndex = nil
        let token = UUID()
        loadToken = token

        let repoPath = repositoryPath
        let staged = mode == .staged
        do {
            let entries = try await Task.detached(priority: .userInitiated) {
                let output = try GitClient.diff(repositoryPath: repoPath, staged: staged)
                return DiffParser.parse(output)
            }.value
            guard loadToken == token else { return }
            state = .loaded(entries)
            selectedFileIndex = entries.isEmpty ? nil : 0
        } catch {
            guard loadToken == token else { return }
            state = .error(error.localizedDescription)
        }
    }

    func selectFile(_ index: Int?) {
        selectedFileIndex = index
    }

    func reset() {
        state = .idle
        selectedFileIndex = nil
        loadToken = UUID()
    }
}
