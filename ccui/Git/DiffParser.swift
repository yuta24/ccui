import Foundation

enum DiffParser {

    nonisolated static func parse(_ output: String) -> [DiffFileEntry] {
        guard !output.isEmpty else { return [] }

        var entries: [DiffFileEntry] = []
        let lines = output.components(separatedBy: "\n")
        var i = 0
        var fileIndex = 0
        var lineIdCounter = 0

        while i < lines.count {
            guard lines[i].hasPrefix("diff --git ") else {
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

    // MARK: - File Entry

    private nonisolated static func parseFileEntry(lines: [String], from start: Int, fileIndex: Int, lineIdCounter: inout Int) -> (DiffFileEntry, Int) {
        var i = start + 1

        var status: DiffFileEntry.Status = .modified
        var isBinary = false
        var renamedOldPath: String?
        var renamedNewPath: String?
        var minusPath: String?
        var plusPath: String?

        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("@@") || line.hasPrefix("diff --git ") { break }

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
            } else if line == "--- /dev/null" {
                minusPath = nil
            } else if line.hasPrefix("+++ b/") {
                plusPath = String(line.dropFirst("+++ b/".count))
            } else if line == "+++ /dev/null" {
                plusPath = nil
            } else if line.contains("Binary files") && line.contains("differ") {
                isBinary = true
            }
            i += 1
        }

        let oldPath: String
        let newPath: String
        if status == .renamed {
            oldPath = renamedOldPath ?? minusPath ?? "unknown"
            newPath = renamedNewPath ?? plusPath ?? "unknown"
        } else if status == .added {
            oldPath = ""
            newPath = plusPath ?? "unknown"
        } else if status == .deleted {
            oldPath = minusPath ?? "unknown"
            newPath = ""
        } else {
            let resolvedPath = plusPath ?? minusPath ?? "unknown"
            oldPath = minusPath ?? resolvedPath
            newPath = plusPath ?? resolvedPath
        }

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

        var additions = 0
        var deletions = 0
        var maxLineNumber = 0
        for hunk in hunks {
            for line in hunk.lines {
                switch line.kind {
                case .addition: additions += 1
                case .deletion: deletions += 1
                case .context: break
                }
            }
            if hunk.maxOldLine > maxLineNumber { maxLineNumber = hunk.maxOldLine }
            if hunk.maxNewLine > maxLineNumber { maxLineNumber = hunk.maxNewLine }
        }

        let entry = DiffFileEntry(
            id: fileIndex,
            status: status,
            oldPath: oldPath,
            newPath: newPath,
            isBinary: isBinary,
            hunks: hunks,
            additions: additions,
            deletions: deletions,
            maxLineNumber: maxLineNumber
        )
        return (entry, i)
    }

    // MARK: - Hunk

    private nonisolated static func parseHunk(lines: [String], from start: Int, hunkIndex: Int, lineIdCounter: inout Int) -> (DiffHunk, Int) {
        let header = lines[start]
        var i = start + 1

        var oldLine = 1
        var newLine = 1
        if header.hasPrefix("@@ "),
           let closingRange = header.range(of: " @@", range: header.index(header.startIndex, offsetBy: 3)..<header.endIndex) {
            let inner = header[header.index(header.startIndex, offsetBy: 3)..<closingRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            let parts = inner.components(separatedBy: " ")
            for part in parts {
                if part.hasPrefix("-") {
                    let nums = part.dropFirst().components(separatedBy: ",")
                    oldLine = Int(nums.first ?? "") ?? 1
                } else if part.hasPrefix("+") {
                    let nums = part.dropFirst().components(separatedBy: ",")
                    newLine = Int(nums.first ?? "") ?? 1
                }
            }
        }

        var diffLines: [DiffLine] = []
        var maxOldLine = 0
        var maxNewLine = 0

        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("diff --git ") || line.hasPrefix("@@") { break }

            if line.hasPrefix("+") {
                diffLines.append(DiffLine(id: lineIdCounter, kind: .addition, oldLineNumber: nil, newLineNumber: newLine, content: String(line.dropFirst())))
                if newLine > maxNewLine { maxNewLine = newLine }
                newLine += 1
                lineIdCounter += 1
            } else if line.hasPrefix("-") {
                diffLines.append(DiffLine(id: lineIdCounter, kind: .deletion, oldLineNumber: oldLine, newLineNumber: nil, content: String(line.dropFirst())))
                if oldLine > maxOldLine { maxOldLine = oldLine }
                oldLine += 1
                lineIdCounter += 1
            } else if line.hasPrefix(" ") || line.isEmpty {
                let content = line.isEmpty ? "" : String(line.dropFirst())
                diffLines.append(DiffLine(id: lineIdCounter, kind: .context, oldLineNumber: oldLine, newLineNumber: newLine, content: content))
                if oldLine > maxOldLine { maxOldLine = oldLine }
                if newLine > maxNewLine { maxNewLine = newLine }
                oldLine += 1
                newLine += 1
                lineIdCounter += 1
            } else if line.hasPrefix("\\") {
                i += 1
                continue
            } else {
                break
            }
            i += 1
        }

        let hunk = DiffHunk(id: hunkIndex, header: header, lines: diffLines, maxOldLine: maxOldLine, maxNewLine: maxNewLine)
        return (hunk, i)
    }
}
