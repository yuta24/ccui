import Foundation

enum GitClient {

    // MARK: - Worktree

    nonisolated static func listWorktrees(repositoryPath: String) throws -> String {
        try run(["worktree", "list", "--porcelain"], at: repositoryPath)
    }

    nonisolated static func addWorktree(args: [String], repositoryPath: String) throws {
        _ = try run(["worktree", "add"] + args, at: repositoryPath)
    }

    nonisolated static func removeWorktree(path: String, repositoryPath: String, force: Bool = false) throws {
        var args = ["worktree", "remove"]
        if force { args.append("--force") }
        args.append(path)
        _ = try run(args, at: repositoryPath)
    }


    // MARK: - Branch

    nonisolated static func listLocalBranches(repositoryPath: String) throws -> [String] {
        let output = try run(["branch", "--format=%(refname:short)"], at: repositoryPath)
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    nonisolated static func defaultBranch(repositoryPath: String) throws -> String? {
        let output = try run(["symbolic-ref", "refs/remotes/origin/HEAD"], at: repositoryPath)
        let ref = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ref.hasPrefix("refs/remotes/origin/") else { return nil }
        return String(ref.dropFirst("refs/remotes/origin/".count))
    }

    // MARK: - Status

    nonisolated static func statusCount(worktreePath: String) throws -> Int {
        let output = try run(["status", "--porcelain"], at: worktreePath)
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }

    // MARK: - Diff

    nonisolated static func diff(repositoryPath: String, staged: Bool) async throws -> String {
        let args = staged ? ["diff", "--cached", "--color=never"] : ["diff", "--color=never"]
        return try await runAsync(args, at: repositoryPath)
    }

    // MARK: - Process

    nonisolated private static func run(_ args: [String], at directoryPath: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directoryPath)

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

    nonisolated private static func runAsync(_ args: [String], at directoryPath: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: directoryPath)

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { terminatedProcess in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()

                if terminatedProcess.terminationStatus != 0 {
                    let errString = String(data: errData, encoding: .utf8) ?? "git command failed"
                    continuation.resume(throwing: GitError.commandFailed(errString.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    continuation.resume(returning: String(data: outData, encoding: .utf8) ?? "")
                }
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}
