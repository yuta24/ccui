import Foundation

@Observable
@MainActor
final class TerminalSessionStore {
    private var sessions: [String: any TerminalSession] = [:]
    private var claudePathTask: Task<String, Never>?

    func startResolvingClaudePath() {
        claudePathTask = Task.detached(priority: .userInitiated) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "which claude"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let resolved = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return resolved.isEmpty ? "claude" : resolved
        }
    }

    func session(for worktree: Worktree) -> (any TerminalSession)? {
        sessions[worktree.path]
    }

    func ensureSession(for worktree: Worktree, sessionId: String, isResume: Bool) async {
        guard sessions[worktree.path] == nil else { return }
        let claudePath = await claudePathTask?.value ?? "claude"
        let args = if isResume {
            ["--resume", sessionId]
        } else {
            ["--session-id", sessionId]
        }
        let session = SwiftTermSession(
            workingDirectory: worktree.path,
            label: "Terminal",
            executable: claudePath,
            args: args
        )
        sessions[worktree.path] = session
    }

    func remove(for path: String) {
        sessions[path]?.terminate()
        sessions.removeValue(forKey: path)
    }

    func removeExcept(paths: Set<String>) {
        let toRemove = sessions.keys.filter { !paths.contains($0) }
        for key in toRemove {
            sessions[key]?.terminate()
            sessions.removeValue(forKey: key)
        }
    }

    func terminateAll() {
        for session in sessions.values {
            session.terminate()
        }
        sessions.removeAll()
    }
}
