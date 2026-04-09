import Foundation

nonisolated struct Worktree: Identifiable, Hashable, Sendable {
    let id: String
    let repositoryID: Repository.ID
    let path: String
    let branch: String?
    let isMain: Bool

    init(repositoryID: Repository.ID, path: String, branch: String?, isMain: Bool) {
        self.id = path
        self.repositoryID = repositoryID
        self.path = path
        self.branch = branch
        self.isMain = isMain
    }

    var displayName: String {
        branch ?? URL(fileURLWithPath: path).lastPathComponent
    }
}
