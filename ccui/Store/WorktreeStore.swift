import Foundation

@Observable
@MainActor
final class WorktreeStore: Identifiable {
    let id: Repository.ID
    private(set) var worktrees: [Worktree] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: Repository
    private var loadToken = UUID()

    init(repository: Repository) {
        self.id = repository.id
        self.repository = repository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        let token = UUID()
        loadToken = token

        let repoPath = repository.path
        let repoID = repository.id
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                let output = try Self.runGit(args: ["worktree", "list", "--porcelain"], repositoryPath: repoPath)
                return Self.parse(output, repositoryID: repoID)
            }.value
            guard loadToken == token else { return }
            worktrees = result
        } catch {
            guard loadToken == token else { return }
            print("[WorktreeStore] Failed to list worktrees: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func add(branch: String, path: String, createBranch: Bool) async throws {
        let repoPath = repository.path
        var args = ["worktree", "add"]
        if createBranch {
            args += ["-b", branch, path]
        } else {
            args += [path, branch]
        }

        try await Task.detached(priority: .userInitiated) {
            _ = try Self.runGit(args: args, repositoryPath: repoPath)
        }.value

        await load()
    }

    func remove(_ worktree: Worktree) async throws {
        let repoPath = repository.path
        let wtPath = worktree.path

        try await Task.detached(priority: .userInitiated) {
            _ = try Self.runGit(args: ["worktree", "remove", wtPath], repositoryPath: repoPath)
        }.value

        await load()
    }

    // MARK: - Git execution

    nonisolated private static func runGit(args: [String], repositoryPath: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: repositoryPath)

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errString = String(data: errData, encoding: .utf8) ?? "git command failed"
            throw GitError.commandFailed(errString.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return String(data: outData, encoding: .utf8) ?? ""
    }

    // MARK: - Porcelain parsing

    nonisolated private static func parse(_ output: String, repositoryID: Repository.ID) -> [Worktree] {
        guard !output.isEmpty else { return [] }

        // Split into blocks separated by blank lines
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
                    if ref.hasPrefix("refs/heads/") {
                        branch = String(ref.dropFirst("refs/heads/".count))
                    } else {
                        branch = ref
                    }
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
