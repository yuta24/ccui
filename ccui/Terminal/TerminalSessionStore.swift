import Foundation

@Observable
@MainActor
final class TerminalSessionStore {
    private var sessions: [String: any TerminalSession] = [:]

    func session(for worktree: Worktree) -> any TerminalSession {
        if let existing = sessions[worktree.path] {
            return existing
        }
        let session = SwiftTermSession(workingDirectory: worktree.path)
        sessions[worktree.path] = session
        return session
    }

    func remove(for path: String) {
        sessions.removeValue(forKey: path)
    }

    func removeExcept(paths: Set<String>) {
        for key in sessions.keys where !paths.contains(key) {
            sessions.removeValue(forKey: key)
        }
    }
}
