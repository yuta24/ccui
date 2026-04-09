import Foundation

@Observable
@MainActor
final class DiffStore {
    enum DiffMode: String, CaseIterable {
        case staged = "Staged"
        case unstaged = "Unstaged"
    }

    enum State {
        case idle
        case loading
        case loaded([DiffFileEntry])
        case error(String)
    }

    private(set) var state: State = .idle
    var selectedFileIndex: Int?
    var mode: DiffMode = .staged
    private var loadToken = UUID()

    func load(repositoryPath: String, mode newMode: DiffMode? = nil) async {
        if let newMode { mode = newMode }
        state = .loading
        selectedFileIndex = nil
        let token = UUID()
        loadToken = token

        let repoPath = repositoryPath
        let currentMode = mode
        do {
            let entries = try await Task.detached(priority: .userInitiated) {
                let output = try Self.runGit(repositoryPath: repoPath, mode: currentMode)
                return Self.parse(output)
            }.value
            guard loadToken == token else { return }
            state = .loaded(entries)
            selectedFileIndex = entries.isEmpty ? nil : 0
        } catch {
            guard loadToken == token else { return }
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
        selectedFileIndex = nil
        loadToken = UUID()
    }

    // MARK: - Git execution

    private nonisolated static func runGit(repositoryPath: String, mode: DiffMode) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = mode == .staged ? ["diff", "--cached"] : ["diff"]
        process.currentDirectoryURL = URL(fileURLWithPath: repositoryPath)

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errString = String(data: errData, encoding: .utf8) ?? "git diff failed"
            throw GitError.commandFailed(errString.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return String(data: outData, encoding: .utf8) ?? ""
    }

    // MARK: - Diff parsing

    private nonisolated static func parse(_ output: String) -> [DiffFileEntry] {
        guard !output.isEmpty else { return [] }

        var entries: [DiffFileEntry] = []
        let lines = output.components(separatedBy: "\n")
        var i = 0
        var fileIndex = 0
        var lineIdCounter = 0

        while i < lines.count {
            let line = lines[i]

            // Start of a new file diff
            guard line.hasPrefix("diff --git ") else {
                i += 1
                continue
            }

            let (entry, nextIndex) = parseFileEntry(lines: lines, from: i, fileIndex: fileIndex, lineIdCounter: &lineIdCounter)
            entries.append(entry)
            fileIndex += 1
            i = nextIndex
        }

        return entries
    }

    private nonisolated static func parseFileEntry(lines: [String], from start: Int, fileIndex: Int, lineIdCounter: inout Int) -> (DiffFileEntry, Int) {
        var i = start
        i += 1

        var status: DiffFileEntry.Status = .modified
        var isBinary = false
        var renamedOldPath: String?
        var renamedNewPath: String?
        var minusPath: String?
        var plusPath: String?

        // Parse header lines until first hunk or next diff
        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("@@") { break }
            if line.hasPrefix("diff --git ") { break }

            if line.hasPrefix("new file mode") {
                status = .added
            } else if line.hasPrefix("deleted file mode") {
                status = .deleted
            } else if line.hasPrefix("rename from ") {
                status = .renamed
                renamedOldPath = String(line.dropFirst("rename from ".count))
            } else if line.hasPrefix("rename to ") {
                renamedNewPath = String(line.dropFirst("rename to ".count))
            } else if line.hasPrefix("--- a/") {
                minusPath = String(line.dropFirst("--- a/".count))
            } else if line.hasPrefix("+++ b/") {
                plusPath = String(line.dropFirst("+++ b/".count))
            } else if line.contains("Binary files") && line.contains("differ") {
                isBinary = true
            }
            i += 1
        }

        // Determine paths: prefer --- / +++ headers, then rename headers
        let oldPath: String
        let newPath: String
        if status == .renamed {
            oldPath = renamedOldPath ?? minusPath ?? "unknown"
            newPath = renamedNewPath ?? plusPath ?? "unknown"
        } else {
            let resolvedPath = plusPath ?? minusPath ?? "unknown"
            oldPath = minusPath ?? resolvedPath
            newPath = plusPath ?? resolvedPath
        }

        // Parse hunks
        var hunks: [DiffHunk] = []
        var hunkIndex = 0
        while i < lines.count && !lines[i].hasPrefix("diff --git ") {
            if lines[i].hasPrefix("@@") {
                let (hunk, nextIndex) = parseHunk(lines: lines, from: i, hunkIndex: hunkIndex, lineIdCounter: &lineIdCounter)
                hunks.append(hunk)
                hunkIndex += 1
                i = nextIndex
            } else {
                i += 1
            }
        }

        let entry = DiffFileEntry(
            id: fileIndex,
            status: status,
            oldPath: oldPath,
            newPath: newPath,
            isBinary: isBinary,
            hunks: hunks
        )
        return (entry, i)
    }

    private nonisolated static func parseHunk(lines: [String], from start: Int, hunkIndex: Int, lineIdCounter: inout Int) -> (DiffHunk, Int) {
        let header = lines[start]
        var i = start + 1

        // Parse line numbers from "@@ -OLD_START,COUNT +NEW_START,COUNT @@"
        var oldLine = 1
        var newLine = 1
        if let atRange = header.range(of: "@@", options: [], range: header.index(header.startIndex, offsetBy: 2)..<header.endIndex) {
            let inner = header[header.index(header.startIndex, offsetBy: 3)..<atRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            let parts = inner.components(separatedBy: " ")
            for part in parts {
                if part.hasPrefix("-") {
                    let nums = part.dropFirst().components(separatedBy: ",")
                    oldLine = Int(nums[0]) ?? 1
                } else if part.hasPrefix("+") {
                    let nums = part.dropFirst().components(separatedBy: ",")
                    newLine = Int(nums[0]) ?? 1
                }
            }
        }

        var diffLines: [DiffLine] = []

        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("diff --git ") || line.hasPrefix("@@") { break }

            if line.hasPrefix("+") {
                diffLines.append(DiffLine(id: lineIdCounter, kind: .addition, oldLineNumber: nil, newLineNumber: newLine, content: String(line.dropFirst())))
                newLine += 1
                lineIdCounter += 1
            } else if line.hasPrefix("-") {
                diffLines.append(DiffLine(id: lineIdCounter, kind: .deletion, oldLineNumber: oldLine, newLineNumber: nil, content: String(line.dropFirst())))
                oldLine += 1
                lineIdCounter += 1
            } else if line.hasPrefix(" ") || line.isEmpty {
                let content = line.isEmpty ? "" : String(line.dropFirst())
                diffLines.append(DiffLine(id: lineIdCounter, kind: .context, oldLineNumber: oldLine, newLineNumber: newLine, content: content))
                oldLine += 1
                newLine += 1
                lineIdCounter += 1
            } else if line.hasPrefix("\\") {
                // "\ No newline at end of file" — skip
                i += 1
                continue
            } else {
                break
            }
            i += 1
        }

        let hunk = DiffHunk(id: hunkIndex, header: header, lines: diffLines)
        return (hunk, i)
    }
}

enum GitError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message): message
        }
    }
}
