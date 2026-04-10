import Foundation

@Observable
@MainActor
final class WorktreeStore: Identifiable {
    let id: Repository.ID
    private(set) var worktrees: [Worktree] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var statusCounts: [String: Int] = [:]

    private(set) var branches: [String] = []
    private(set) var defaultBranch: String?
    private(set) var isLoadingBranches = false

    let repositoryPath: String
    private let repository: Repository
    private var loadToken = UUID()
    nonisolated(unsafe) private var headWatchers: [DispatchSourceFileSystemObject] = []
    private var reloadTask: Task<Void, Never>?

    init(repository: Repository) {
        self.id = repository.id
        self.repositoryPath = repository.path
        self.repository = repository
    }

    deinit {
        for watcher in headWatchers {
            watcher.cancel()
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        let token = UUID()
        loadToken = token

        let repoPath = repository.path
        let repoID = repository.id
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                let output = try GitClient.listWorktrees(repositoryPath: repoPath)
                return Self.parse(output, repositoryID: repoID)
            }.value
            guard loadToken == token else { return }
            worktrees = result
        } catch {
            guard loadToken == token else { return }
            errorMessage = error.localizedDescription
        }

        await loadStatus()
    }

    func add(branch: String, path: String, createBranch: Bool, startPoint: String? = nil) async throws {
        let repoPath = repository.path
        var args: [String] = []
        if createBranch {
            args = ["-b", branch, path]
            if let startPoint, !startPoint.isEmpty {
                args.append(startPoint)
            }
        } else {
            args = [path, branch]
        }

        try await Task.detached(priority: .userInitiated) {
            try GitClient.addWorktree(args: args, repositoryPath: repoPath)
        }.value

        await load()
        startWatching()
    }

    func loadBranches() async {
        isLoadingBranches = true
        defer { isLoadingBranches = false }
        let repoPath = repository.path
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                let branches = try GitClient.listLocalBranches(repositoryPath: repoPath)
                let defaultBranch = try? GitClient.defaultBranch(repositoryPath: repoPath)
                return (branches, defaultBranch)
            }.value
            branches = result.0
            defaultBranch = result.1
        } catch {
            branches = []
            defaultBranch = nil
        }
    }

    func remove(_ worktree: Worktree, force: Bool = false) async throws {
        let repoPath = repository.path
        let wtPath = worktree.path
        let branch = worktree.branch

        try await Task.detached(priority: .userInitiated) {
            if !force {
                let count = try GitClient.statusCount(worktreePath: wtPath)
                if count > 0 {
                    throw GitError.worktreeDirty(wtPath)
                }
            }
            try GitClient.removeWorktree(path: wtPath, repositoryPath: repoPath, force: force)
        }.value

        await load()
        startWatching()
    }

    // MARK: - File Watching

    func startWatching() {
        stopWatching()

        let gitDir = (repositoryPath as NSString).appendingPathComponent(".git")

        // Watch .git/ directory for main worktree HEAD changes (atomic rename)
        var watchDirs = [gitDir]

        // Watch .git/worktrees/ directory itself for new worktree additions
        let worktreesDir = (gitDir as NSString).appendingPathComponent("worktrees")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: worktreesDir, isDirectory: &isDir), isDir.boolValue {
            watchDirs.append(worktreesDir)

            // Watch each linked worktree directory for HEAD changes
            if let entries = try? FileManager.default.contentsOfDirectory(atPath: worktreesDir) {
                for entry in entries {
                    let dir = (worktreesDir as NSString).appendingPathComponent(entry)
                    var entryIsDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: dir, isDirectory: &entryIsDir), entryIsDir.boolValue {
                        watchDirs.append(dir)
                    }
                }
            }
        }

        for dir in watchDirs {
            let fd = open(dir, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: .write,
                queue: .global(qos: .utility)
            )
            source.setEventHandler { [weak self] in
                self?.scheduleReload()
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            headWatchers.append(source)
        }
    }

    private func stopWatching() {
        for watcher in headWatchers {
            watcher.cancel()
        }
        headWatchers.removeAll()
    }

    nonisolated private func scheduleReload() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.reloadTask?.cancel()
            self.reloadTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await self.load()
                self.startWatching()
            }
        }
    }

    // MARK: - Status

    private func loadStatus() async {
        let token = loadToken
        let currentWorktrees = worktrees
        var results: [String: Int] = [:]
        await withTaskGroup(of: (String, Int?).self) { group in
            for wt in currentWorktrees {
                let wtPath = wt.path
                group.addTask {
                    let count = try? GitClient.statusCount(worktreePath: wtPath)
                    return (wtPath, count)
                }
            }
            for await (path, count) in group {
                if let count {
                    results[path] = count
                }
            }
        }
        guard loadToken == token else { return }
        statusCounts = results
    }

    // MARK: - Parsing

    nonisolated private static func parse(_ output: String, repositoryID: Repository.ID) -> [Worktree] {
        guard !output.isEmpty else { return [] }

        let blocks = output.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var worktrees: [Worktree] = []
        for (index, block) in blocks.enumerated() {
            let lines = block.components(separatedBy: "\n")
            var path: String?
            var branch: String?

            for line in lines {
                if line.hasPrefix("worktree ") {
                    path = String(line.dropFirst("worktree ".count))
                } else if line.hasPrefix("branch ") {
                    let ref = String(line.dropFirst("branch ".count))
                    branch = ref.hasPrefix("refs/heads/") ? String(ref.dropFirst("refs/heads/".count)) : ref
                } else if line == "detached" {
                    branch = nil
                }
            }

            guard let worktreePath = path else { continue }

            worktrees.append(Worktree(
                repositoryID: repositoryID,
                path: worktreePath,
                branch: branch,
                isMain: index == 0
            ))
        }

        return worktrees
    }
}
