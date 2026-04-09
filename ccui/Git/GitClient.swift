import Foundation

enum GitClient {

    // MARK: - Worktree

    nonisolated static func listWorktrees(repositoryPath: String) throws -> String {
        try run(["worktree", "list", "--porcelain"], at: repositoryPath)
    }

    nonisolated static func addWorktree(args: [String], repositoryPath: String) throws {
        _ = try run(["worktree", "add"] + args, at: repositoryPath)
    }

    nonisolated static func removeWorktree(path: String, repositoryPath: String) throws {
        _ = try run(["worktree", "remove", path], at: repositoryPath)
    }

    // MARK: - Status

    nonisolated static func statusCount(worktreePath: String) throws -> Int {
        let output = try run(["status", "--porcelain"], at: worktreePath)
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }

    // MARK: - Diff

    nonisolated static func diff(repositoryPath: String, staged: Bool) throws -> String {
        let args = staged ? ["diff", "--cached"] : ["diff"]
        return try run(args, at: repositoryPath)
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
}
