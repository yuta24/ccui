import Foundation

@Observable
@MainActor
final class WorktreeStore: Identifiable {
    let id: Repository.ID
    private(set) var worktrees: [Worktree] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var statusCounts: [String: Int] = [:]

    private let repository: Repository
    private var loadToken = UUID()

    init(repository: Repository) {
        self.id = repository.id
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        statusCounts = [:]
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

    func add(branch: String, path: String, createBranch: Bool) async throws {
        let repoPath = repository.path
        var args: [String] = []
        if createBranch {
            args = ["-b", branch, path]
        } else {
            args = [path, branch]
        }

        try await Task.detached(priority: .userInitiated) {
            try GitClient.addWorktree(args: args, repositoryPath: repoPath)
        }.value

        await load()
    }

    func remove(_ worktree: Worktree) async throws {
        let repoPath = repository.path
        let wtPath = worktree.path

        try await Task.detached(priority: .userInitiated) {
            try GitClient.removeWorktree(path: wtPath, repositoryPath: repoPath)
        }.value

        await load()
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
