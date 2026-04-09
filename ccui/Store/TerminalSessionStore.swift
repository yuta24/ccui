import Foundation

@Observable
@MainActor
final class TerminalSessionStore {
    private var sessions: [String: [any TerminalSession]] = [:]
    private var selectedIndices: [String: Int] = [:]
    private var nextLabelNumber: [String: Int] = [:]

    func sessions(for worktree: Worktree) -> [any TerminalSession] {
        sessions[worktree.path] ?? []
    }

    func ensureSession(for worktree: Worktree) {
        if sessions[worktree.path] == nil || sessions[worktree.path]!.isEmpty {
            let number = nextNumber(for: worktree.path)
            let session = SwiftTermSession(workingDirectory: worktree.path, label: "Shell \(number)")
            sessions[worktree.path] = [session]
            selectedIndices[worktree.path] = 0
        }
    }

    func selectedIndex(for worktree: Worktree) -> Int {
        selectedIndices[worktree.path] ?? 0
    }

    func selectSession(at index: Int, for worktree: Worktree) {
        let list = sessions[worktree.path] ?? []
        guard list.indices.contains(index) else { return }
        selectedIndices[worktree.path] = index
    }

    func addSession(for worktree: Worktree) {
        let number = nextNumber(for: worktree.path)
        let session = SwiftTermSession(workingDirectory: worktree.path, label: "Shell \(number)")
        if sessions[worktree.path] == nil {
            sessions[worktree.path] = []
        }
        sessions[worktree.path]!.append(session)
        selectedIndices[worktree.path] = sessions[worktree.path]!.count - 1
    }

    func removeSession(at index: Int, for worktree: Worktree) {
        guard var list = sessions[worktree.path], list.count > 1, list.indices.contains(index) else { return }
        list[index].terminate()
        list.remove(at: index)
        sessions[worktree.path] = list

        let selected = selectedIndices[worktree.path] ?? 0
        if selected >= list.count {
            selectedIndices[worktree.path] = list.count - 1
        } else if selected == index {
            selectedIndices[worktree.path] = max(0, index - 1)
        } else if selected > index {
            selectedIndices[worktree.path] = selected - 1
        }
    }

    func remove(for path: String) {
        if let list = sessions[path] {
            for session in list { session.terminate() }
        }
        sessions.removeValue(forKey: path)
        selectedIndices.removeValue(forKey: path)
        nextLabelNumber.removeValue(forKey: path)
    }

    func removeExcept(paths: Set<String>) {
        for key in sessions.keys where !paths.contains(key) {
            if let list = sessions[key] {
                for session in list { session.terminate() }
            }
            sessions.removeValue(forKey: key)
            selectedIndices.removeValue(forKey: key)
            nextLabelNumber.removeValue(forKey: key)
        }
    }

    private func nextNumber(for path: String) -> Int {
        let number = (nextLabelNumber[path] ?? 0) + 1
        nextLabelNumber[path] = number
        return number
    }
}
