import Foundation

enum GitError: LocalizedError {
    case commandFailed(String)
    case worktreeDirty(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message): message
        case .worktreeDirty: "Worktree has uncommitted changes."
        case .timeout: "Git command timed out."
        }
    }
}
