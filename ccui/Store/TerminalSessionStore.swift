import Foundation

@Observable
@MainActor
final class TerminalSessionStore {
    private var sessions: [String: any TerminalSession] = [:]

    func session(for worktree: Worktree) -> (any TerminalSession)? {
        sessions[worktree.path]
    }

    func ensureSession(for worktree: Worktree) {
        guard sessions[worktree.path] == nil else { return }
        sessions[worktree.path] = SwiftTermSession(workingDirectory: worktree.path, label: "Terminal")
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
}
