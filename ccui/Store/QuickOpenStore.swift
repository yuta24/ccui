import Foundation

nonisolated struct QuickOpenResult: Identifiable, Equatable, Sendable {
    let id: UUID
    let node: FileNode
    let score: Int
    let matchedIndices: [String.Index]

    init(node: FileNode, score: Int, matchedIndices: [String.Index]) {
        self.id = node.id
        self.node = node
        self.score = score
        self.matchedIndices = matchedIndices
    }
}

@Observable
@MainActor
final class QuickOpenStore {
    var isVisible = false
    var query = "" {
        didSet { search() }
    }
    private(set) var results: [QuickOpenResult] = []
    private(set) var isIndexing = false
    private var index: [FileNode] = []
    private var searchTask: Task<Void, Never>?
    private var indexTask: Task<Void, Never>?

    func open() {
        isVisible = true
        query = ""
        results = []
    }

    func close() {
        isVisible = false
        query = ""
        results = []
    }

    func buildIndex(rootPath: String) {
        indexTask?.cancel()
        indexTask = Task {
            isIndexing = true
            let flat = await Task.detached(priority: .userInitiated) {
                Self.collectAllFiles(at: rootPath)
            }.value
            guard !Task.isCancelled else {
                isIndexing = false
                return
            }
            index = flat
            isIndexing = false
        }
    }

    func clearIndex() {
        indexTask?.cancel()
        indexTask = nil
        index = []
        results = []
        isIndexing = false
    }

    private func search() {
        searchTask?.cancel()

        let q = query
        guard !q.isEmpty else {
            results = []
            return
        }

        let currentIndex = index
        searchTask = Task.detached(priority: .userInitiated) {
            let queryLower = q.lowercased()
            var scored: [QuickOpenResult] = []

            for node in currentIndex {
                if Task.isCancelled { return }
                if let (score, indices) = Self.fuzzyScore(query: queryLower, candidate: node.name) {
                    scored.append(QuickOpenResult(node: node, score: score, matchedIndices: indices))
                }
            }

            scored.sort { $0.score > $1.score }
            let top = Array(scored.prefix(50))

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.results = top
            }
        }
    }

    // MARK: - File Collection

    private nonisolated static func collectAllFiles(at path: String) -> [FileNode] {
        let fm = FileManager.default
        let skipDirs: Set<String> = ["node_modules", ".build", "DerivedData", "Pods", ".git"]
        return collectFilesRecursive(at: path, fm: fm, skipDirs: skipDirs)
    }

    private nonisolated static func collectFilesRecursive(at path: String, fm: FileManager, skipDirs: Set<String>) -> [FileNode] {
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        var result: [FileNode] = []

        for name in contents where !name.hasPrefix(".") {
            if skipDirs.contains(name) { continue }
            let fullPath = (path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                result += collectFilesRecursive(at: fullPath, fm: fm, skipDirs: skipDirs)
            } else {
                result.append(FileNode(name: name, path: fullPath, isDirectory: false))
            }
        }
        return result
    }

    // MARK: - Fuzzy Matching

    nonisolated static func fuzzyScore(query: String, candidate: String) -> (score: Int, matchedIndices: [String.Index])? {
        var queryIndex = query.startIndex
        var candidateIndex = candidate.startIndex
        var matchedIndices: [String.Index] = []
        var score = 0
        var prevMatchIndex: String.Index?

        while queryIndex < query.endIndex && candidateIndex < candidate.endIndex {
            if query[queryIndex].lowercased() == candidate[candidateIndex].lowercased() {
                matchedIndices.append(candidateIndex)

                if candidateIndex == candidate.startIndex {
                    score += 15
                } else if let prev = prevMatchIndex, candidate.index(after: prev) == candidateIndex {
                    score += 10
                } else {
                    let prevChar = candidate[candidate.index(before: candidateIndex)]
                    if prevChar == "/" || prevChar == "." || prevChar == "-" || prevChar == "_" {
                        score += 8
                    } else {
                        score += 5
                    }
                }

                prevMatchIndex = candidateIndex
                queryIndex = query.index(after: queryIndex)
            }
            candidateIndex = candidate.index(after: candidateIndex)
        }

        guard queryIndex == query.endIndex else { return nil }

        let lengthPenalty = max(0, candidate.count - 20)
        score -= lengthPenalty / 3

        return (score, matchedIndices)
    }
}
