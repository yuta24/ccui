import Foundation

@Observable
@MainActor
final class TerminalSessionStore {
    private var sessions: [Repository.ID: any TerminalSession] = [:]

    func session(for repository: Repository) -> any TerminalSession {
        if let existing = sessions[repository.id] {
            return existing
        }
        let session = SwiftTermSession(workingDirectory: repository.path)
        sessions[repository.id] = session
        return session
    }

    func remove(for id: Repository.ID) {
        sessions.removeValue(forKey: id)
    }

    func removeExcept(ids: Set<Repository.ID>) {
        for key in sessions.keys where !ids.contains(key) {
            sessions.removeValue(forKey: key)
        }
    }
}
