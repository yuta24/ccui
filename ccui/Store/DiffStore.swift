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
    private(set) var isDirty: Bool = false
    var mode: DiffMode = .staged
    private var loadToken = UUID()
    private var watcher: FileWatcherService?
    private var currentRepositoryPath: String?

    func load(repositoryPath: String, mode newMode: DiffMode? = nil) async {
        if let newMode { mode = newMode }
        isDirty = false
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

    var needsLoad: Bool {
        if isDirty { return true }
        if case .idle = state { return true }
        return false
    }

    func selectFile(_ index: Int?) {
        selectedFileIndex = index
    }

    func startWatching(repositoryPath: String, panelIsOpen: @escaping @MainActor () -> Bool) {
        stopWatching()
        currentRepositoryPath = repositoryPath
        let watcher = FileWatcherService()
        self.watcher = watcher
        watcher.start(path: repositoryPath) { [weak self] in
            guard let self, let path = self.currentRepositoryPath else { return }
            if panelIsOpen() {
                Task { await self.load(repositoryPath: path) }
            } else {
                self.isDirty = true
            }
        }
    }

    func stopWatching() {
        watcher?.stop()
        watcher = nil
    }

    func reset() {
        state = .idle
        selectedFileIndex = nil
        isDirty = false
        loadToken = UUID()
        currentRepositoryPath = nil
        stopWatching()
    }
}
