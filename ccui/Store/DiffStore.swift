import Foundation

@Observable
@MainActor
final class DiffStore {
    enum State {
        case idle
        case loading
        case loaded([DiffFileEntry])
        case error(String)
    }

    private(set) var state: State = .idle {
        didSet { stateVersion += 1 }
    }
    private(set) var stateVersion: Int = 0
    private(set) var selectedFilePath: String?
    private(set) var isDirty: Bool = false
    private var loadToken = UUID()
    private var watcher: FileWatcherService?
    private var currentRepositoryPath: String?

    func load(repositoryPath: String) async {
        isDirty = false
        state = .loading
        selectedFilePath = nil
        let token = UUID()
        loadToken = token

        let repoPath = repositoryPath
        do {
            let entries = try await Task.detached(priority: .userInitiated) {
                async let diffOutput = GitClient.diff(repositoryPath: repoPath)
                async let untrackedPaths = GitClient.untrackedFiles(repositoryPath: repoPath)

                var result = DiffParser.parse(try await diffOutput)
                let trackedPaths = Set(result.map(\.newPath) + result.map(\.oldPath))
                var nextID = result.count
                for path in try await untrackedPaths where !trackedPaths.contains(path) {
                    result.append(DiffFileEntry(
                        id: nextID, status: .untracked,
                        oldPath: "", newPath: path,
                        isBinary: false, hunks: [],
                        additions: 0, deletions: 0
                    ))
                    nextID += 1
                }
                return result
            }.value
            guard loadToken == token else { return }
            state = .loaded(entries)
            selectedFilePath = entries.first?.newPath
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

    func selectFile(_ path: String?) {
        selectedFilePath = path
    }

    func startWatching(repositoryPath: String, overlayIsVisible: @escaping @MainActor () -> Bool) {
        stopWatching()
        currentRepositoryPath = repositoryPath
        let watcher = FileWatcherService()
        self.watcher = watcher
        watcher.start(path: repositoryPath) { [weak self] in
            guard let self, let path = self.currentRepositoryPath else { return }
            if overlayIsVisible() {
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
        selectedFilePath = nil
        isDirty = false
        loadToken = UUID()
        currentRepositoryPath = nil
        stopWatching()
    }
}
