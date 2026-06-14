import Foundation

@Observable
@MainActor
final class SearchStore {
    enum Mode: Equatable {
        case files
        case content
    }

    var isActive = false
    var mode: Mode = .files
    var query = "" {
        didSet { performSearch() }
    }

    private(set) var fileResults: [QuickOpenResult] = []
    private(set) var contentResults: [ContentSearchResult] = []
    private(set) var isSearching = false

    private var searchTask: Task<Void, Never>?
    private var fileIndex: [FileNode] = []
    private var indexTask: Task<Void, Never>?
    private var rootPath: String = ""

    func activate(mode: Mode) {
        self.mode = mode
        isActive = true
        query = ""
        fileResults = []
        contentResults = []
    }

    func deactivate() {
        isActive = false
        searchTask?.cancel()
        searchTask = nil
        query = ""
        fileResults = []
        contentResults = []
        isSearching = false
    }

    func buildIndex(rootPath: String) {
        self.rootPath = rootPath
        indexTask?.cancel()
        indexTask = Task {
            let flat = await GitFileIndexCache.shared.index(for: rootPath).searchableFiles
            guard !Task.isCancelled else { return }
            fileIndex = flat
        }
    }

    func clearIndex() {
        indexTask?.cancel()
        indexTask = nil
        fileIndex = []
        rootPath = ""
        deactivate()
    }

    // MARK: - Search Dispatch

    private func performSearch() {
        searchTask?.cancel()
        isSearching = false

        let q = query
        guard !q.isEmpty else {
            fileResults = []
            contentResults = []
            return
        }

        switch mode {
        case .files:
            searchFiles(query: q)
        case .content:
            searchContent(query: q)
        }
    }

    // MARK: - File Search

    private func searchFiles(query: String) {
        let currentIndex = fileIndex
        searchTask = Task.detached(priority: .userInitiated) {
            // 連続したキー入力ごとに 50k 件規模の index を全件スコアリングするのを避けるため、
            // 短い debounce を挟んで最後の入力だけを処理する。
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }

            let queryLower = query.lowercased()
            var scored: [QuickOpenResult] = []

            for node in currentIndex {
                if Task.isCancelled { return }
                if let (score, indices) = QuickOpenStore.fuzzyScore(query: queryLower, candidate: node.name) {
                    scored.append(QuickOpenResult(node: node, score: score, matchedIndices: indices))
                }
            }

            scored.sort { $0.score > $1.score }
            let top = Array(scored.prefix(100))

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.fileResults = top
            }
        }
    }

    // MARK: - Content Search

    private func searchContent(query: String) {
        guard query.count >= 2 else {
            contentResults = []
            isSearching = false
            return
        }

        let root = rootPath
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let results = await Self.runContentSearch(query: query, rootPath: root)

            guard !Task.isCancelled else { return }
            contentResults = results
            isSearching = false
        }
    }

    // MARK: - Content Search Process

    /// `rg` が利用可能ならそれを優先する（`.gitignore` を尊重しつつ未追跡ファイルも高速に検索できる）。
    /// 利用できない場合は `git grep` にフォールバックする（追跡済みファイルのみ）。
    private nonisolated static func runContentSearch(query: String, rootPath: String) async -> [ContentSearchResult] {
        let process = Process()
        if let rgPath = await SearchToolLocator.shared.ripgrepPath() {
            process.executableURL = URL(fileURLWithPath: rgPath)
            process.arguments = ["--hidden", "--glob", "!.git", "-n", "-F", "--no-heading", "--color=never", "--", query]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["grep", "-rnIF", "--color=never", "--", query]
        }
        process.currentDirectoryURL = URL(fileURLWithPath: rootPath)

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }

        let data = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in
                    let output = stdout.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: output)
                }
            }
        } onCancel: {
            process.terminate()
        }

        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
            return []
        }

        var fileGroups: [String: [ContentSearchMatch]] = [:]
        var fileOrder: [String] = []
        var totalMatches = 0
        let maxMatches = 1000

        let lineNumPattern = try? NSRegularExpression(pattern: ":(\\d+):")

        for line in output.components(separatedBy: "\n") {
            guard totalMatches < maxMatches, !line.isEmpty else {
                if totalMatches >= maxMatches { break }
                continue
            }

            guard let match = lineNumPattern?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let lineNumRange = Range(match.range(at: 1), in: line) else { continue }

            let filePart = String(line[..<line.index(before: lineNumRange.lowerBound)])
            guard let lineNum = Int(line[lineNumRange]) else { continue }
            let contentStart = line.index(after: lineNumRange.upperBound)
            let content = contentStart < line.endIndex ? String(line[contentStart...]) : ""

            let fullPath = (rootPath as NSString).appendingPathComponent(filePart)

            if fileGroups[fullPath] == nil {
                fileGroups[fullPath] = []
                fileOrder.append(fullPath)
            }
            fileGroups[fullPath]?.append(ContentSearchMatch(filePath: fullPath, lineNumber: lineNum, lineContent: content))
            totalMatches += 1
        }

        return fileOrder.map { path in
            let matches = fileGroups[path] ?? []
            let fileName = (path as NSString).lastPathComponent
            let relativePath: String
            if path.hasPrefix(rootPath + "/") {
                relativePath = String(path.dropFirst(rootPath.count + 1))
            } else {
                relativePath = path
            }
            return ContentSearchResult(filePath: path, fileName: fileName, relativePath: relativePath, matches: matches)
        }
    }
}
