import Foundation

nonisolated enum DiffLineKind: Hashable, Sendable {
    case context
    case addition
    case deletion
}

nonisolated struct DiffLine: Identifiable, Hashable, Sendable {
    let id: Int
    let kind: DiffLineKind
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let content: String
}

nonisolated struct DiffHunk: Identifiable, Hashable, Sendable {
    let id: Int
    let header: String
    let lines: [DiffLine]
}

nonisolated struct DiffFileEntry: Identifiable, Hashable, Sendable {
    nonisolated enum Status: Hashable, Sendable {
        case added, modified, deleted, renamed, untracked
    }

    let id: Int
    let status: Status
    let oldPath: String
    let newPath: String
    let isBinary: Bool
    let hunks: [DiffHunk]
    let additions: Int
    let deletions: Int
}
