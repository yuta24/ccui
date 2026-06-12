import Foundation

enum GitClient {

    // MARK: - Worktree

    nonisolated static func listWorktrees(repositoryPath: String) async throws -> String {
        try await run(["worktree", "list", "--porcelain"], at: repositoryPath)
    }

    nonisolated static func addWorktree(args: [String], repositoryPath: String) async throws {
        _ = try await run(["worktree", "add"] + args, at: repositoryPath)
    }

    nonisolated static func removeWorktree(path: String, repositoryPath: String, force: Bool = false) async throws {
        var args = ["worktree", "remove"]
        if force { args.append("--force") }
        args.append(path)
        _ = try await run(args, at: repositoryPath)
    }

    // MARK: - Branch

    nonisolated static func listLocalBranches(repositoryPath: String) async throws -> [String] {
        let output = try await run(["branch", "--format=%(refname:short)"], at: repositoryPath)
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    nonisolated static func defaultBranch(repositoryPath: String) async throws -> String? {
        let output = try await run(["symbolic-ref", "refs/remotes/origin/HEAD"], at: repositoryPath)
        let ref = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ref.hasPrefix("refs/remotes/origin/") else { return nil }
        return String(ref.dropFirst("refs/remotes/origin/".count))
    }

    // MARK: - Status

    nonisolated static func statusCount(worktreePath: String) async throws -> Int {
        let output = try await run(["status", "--porcelain"], at: worktreePath)
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }

    // MARK: - File Listing

    nonisolated static func lsFiles(_ args: [String], at repositoryPath: String) async throws -> String {
        try await run(["ls-files"] + args, at: repositoryPath)
    }

    // MARK: - Diff

    nonisolated static func diff(repositoryPath: String) async throws -> String {
        do {
            return try await run(["diff", "HEAD", "--color=never"], at: repositoryPath)
        } catch let error as GitError {
            // HEAD doesn't exist (empty repo with no commits)
            if case .commandFailed(let msg) = error, msg.contains("unknown revision") {
                return ""
            }
            throw error
        }
    }

    nonisolated static func untrackedFiles(repositoryPath: String) async throws -> [String] {
        let output = try await run(["ls-files", "--others", "--exclude-standard"], at: repositoryPath)
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    // MARK: - Process

    private nonisolated static let processTimeout: TimeInterval = 30

    nonisolated private static func run(_ args: [String], at directoryPath: String) async throws -> String {
        let output: AsyncProcess.Output
        do {
            output = try await AsyncProcess.run(
                "/usr/bin/git",
                arguments: args,
                currentDirectory: directoryPath,
                timeout: processTimeout
            )
        } catch is AsyncProcess.RunError {
            throw GitError.timeout
        }

        if output.exitCode != 0 {
            throw GitError.commandFailed(output.stderrString.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return output.stdoutString
    }
}
