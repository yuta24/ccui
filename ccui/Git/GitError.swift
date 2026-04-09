import Foundation

enum GitError: LocalizedError {
    case commandFailed(String)
    case worktreeDirty(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message): message
        case .worktreeDirty: "Worktree has uncommitted changes."
        }
    }
}
