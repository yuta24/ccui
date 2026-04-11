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
            let flat = await Task.detached(priority: .userInitiated) {
                Self.collectAllFiles(at: rootPath)
            }.value
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

            let results = await Task.detached(priority: .userInitiated) {
                Self.runGrep(query: query, rootPath: root)
            }.value

            guard !Task.isCancelled else { return }
            contentResults = results
            isSearching = false
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

    // MARK: - Grep

    private nonisolated static func runGrep(query: String, rootPath: String) -> [ContentSearchResult] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        process.arguments = [
            "-rnIF",
            "--color=never",
            "--exclude-dir=node_modules",
            "--exclude-dir=.git",
            "--exclude-dir=.build",
            "--exclude-dir=DerivedData",
            "--exclude-dir=Pods",
            query,
            rootPath
        ]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }

        if Task.isCancelled {
            process.terminate()
            return []
        }

        // Read stdout before waitUntilExit to prevent pipe buffer deadlock
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
            return []
        }

        let rootPrefix = rootPath + "/"
        var fileGroups: [String: [ContentSearchMatch]] = [:]
        var fileOrder: [String] = []
        var totalMatches = 0
        let maxMatches = 1000

        // grep output format: /absolute/path/to/file:linenum:content
        // Parse by stripping the known rootPrefix, then finding `:digits:` pattern
        let lineNumPattern = try? NSRegularExpression(pattern: ":(\\d+):")

        for line in output.components(separatedBy: "\n") {
            guard totalMatches < maxMatches, !line.isEmpty else {
                if totalMatches >= maxMatches { break }
                continue
            }
            guard line.hasPrefix(rootPrefix) else { continue }

            let rest = String(line.dropFirst(rootPrefix.count))

            // Find the first :digits: pattern to split path from line number
            guard let match = lineNumPattern?.firstMatch(in: rest, range: NSRange(rest.startIndex..., in: rest)),
                  let lineNumRange = Range(match.range(at: 1), in: rest) else { continue }

            let filePart = String(rest[..<rest.index(before: lineNumRange.lowerBound)])
            guard let lineNum = Int(rest[lineNumRange]) else { continue }
            let contentStart = rest.index(after: lineNumRange.upperBound)
            let content = contentStart < rest.endIndex ? String(rest[contentStart...]) : ""

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
            if path.hasPrefix(rootPrefix) {
                relativePath = String(path.dropFirst(rootPrefix.count))
            } else {
                relativePath = path
            }
            return ContentSearchResult(filePath: path, fileName: fileName, relativePath: relativePath, matches: matches)
        }
    }
}
