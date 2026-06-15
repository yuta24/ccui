import Foundation
import OSLog

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
    private let eventBus: AppEventBus
    private var loadToken = UUID()
    private let watcher = FileSystemWatcher()
    private var reloadTask: Task<Void, Never>?

    init(repository: Repository, eventBus: AppEventBus) {
        self.id = repository.id
        self.repositoryPath = repository.path
        self.repository = repository
        self.eventBus = eventBus
    }

    func tearDown() {
        reloadTask?.cancel()
        reloadTask = nil
        stopWatching()
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
                let output = try await GitClient.listWorktrees(repositoryPath: repoPath)
                return Self.parse(output, repositoryID: repoID)
            }.value
            guard loadToken == token else { return }
            worktrees = result
        } catch {
            guard loadToken == token else { return }
            errorMessage = error.localizedDescription
        }

        await loadStatus()
        guard loadToken == token else { return }

        let paths = worktrees.map(\.path)
        let installErrors: [(String, Error)] = await Task.detached(priority: .utility) {
            var errors: [(String, Error)] = []
            for path in paths {
                do {
                    try ClaudeHooksInstaller.install(worktreePath: path)
                } catch {
                    errors.append((path, error))
                }
            }
            return errors
        }.value
        guard loadToken == token else { return }

        for (path, error) in installErrors {
            Logger.store.error("Failed to install hooks for \(path, privacy: .public): \(error)")
            errorMessage = "Hook install failed: \(error.localizedDescription)"
        }

        eventBus.publish(.worktreesLoaded(repositoryPath: repository.path, paths: Set(worktrees.map(\.path))))
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
            try await GitClient.addWorktree(args: args, repositoryPath: repoPath)
        }.value

        reloadTask?.cancel()
        reloadTask = nil
        stopWatching()
        await load()
        startWatching()
    }

    func loadBranches() async {
        isLoadingBranches = true
        defer { isLoadingBranches = false }
        let repoPath = repository.path
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                let branches = try await GitClient.listLocalBranches(repositoryPath: repoPath)
                let defaultBranch = try? await GitClient.defaultBranch(repositoryPath: repoPath)
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

        try await Task.detached(priority: .userInitiated) {
            var gitForce = force
            if !force {
                let count = try await GitClient.statusCount(worktreePath: wtPath)
                if count > 0 {
                    throw GitError.worktreeDirty(wtPath)
                }
                // statusCount は ClaudeHooksInstaller が生成する
                // .claude/settings.local.json を無視するが、git 自身の
                // dirty チェックはこのファイルを見て拒否するため、
                // ユーザー視点で clean と判定できた場合は force で回避する。
                gitForce = true
            }
            try await GitClient.removeWorktree(path: wtPath, repositoryPath: repoPath, force: gitForce)
        }.value

        reloadTask?.cancel()
        reloadTask = nil
        stopWatching()
        await load()
        startWatching()
    }

    // MARK: - File Watching

    func startWatching() {
        watcher.start(paths: Self.watchPaths(repositoryPath: repositoryPath), fileEvents: false, debounce: nil) { [weak self] in
            self?.scheduleReload()
        }
    }

    func stopWatching() {
        watcher.stop()
    }

    /// `.git` および `.git/worktrees` 配下の各 worktree ディレクトリを監視対象として返す。
    nonisolated private static func watchPaths(repositoryPath: String) -> [String] {
        let gitDir = (repositoryPath as NSString).appendingPathComponent(".git")
        var paths = [gitDir]

        let worktreesDir = (gitDir as NSString).appendingPathComponent("worktrees")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: worktreesDir, isDirectory: &isDir), isDir.boolValue else {
            return paths
        }
        paths.append(worktreesDir)

        if let entries = try? FileManager.default.contentsOfDirectory(atPath: worktreesDir) {
            for entry in entries {
                let dir = (worktreesDir as NSString).appendingPathComponent(entry)
                var entryIsDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: dir, isDirectory: &entryIsDir), entryIsDir.boolValue {
                    paths.append(dir)
                }
            }
        }
        return paths
    }

    nonisolated private func scheduleReload() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.reloadTask?.cancel()
            self.reloadTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                self.stopWatching()
                defer { self.startWatching() }
                await self.load()
            }
        }
    }

    // MARK: - Status

    private func loadStatus() async {
        let token = loadToken
        let currentWorktrees = worktrees
        let results = await Task.detached(priority: .utility) {
            var map: [String: Int] = [:]
            await withTaskGroup(of: (String, Int?).self) { group in
                for wt in currentWorktrees {
                    let wtPath = wt.path
                    group.addTask {
                        let count = try? await GitClient.statusCount(worktreePath: wtPath)
                        return (wtPath, count)
                    }
                }
                for await (path, count) in group {
                    if let count {
                        map[path] = count
                    }
                }
            }
            return map
        }.value
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
