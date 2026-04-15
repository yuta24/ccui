import Foundation
import OSLog

enum ClaudeMdLevel: String, Sendable, CaseIterable, Identifiable {
    case user = "User"
    case project = "Project"
    case projectLocal = "Project Local"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .user: "~/.claude/CLAUDE.md — applies to all projects"
        case .project: "CLAUDE.md — checked into the repository"
        case .projectLocal: ".claude/CLAUDE.md — gitignored, local only"
        }
    }
}

struct ClaudeMdFile: Identifiable, Sendable {
    let id: ClaudeMdLevel
    let level: ClaudeMdLevel
    let path: String
    let exists: Bool
    let content: String?
    let modifiedAt: Date?
}

@Observable
@MainActor
final class ClaudeMdStore {
    private(set) var files: [ClaudeMdFile] = []
    var selectedLevel: ClaudeMdLevel?
    var editorContent: String = ""
    var isDirty: Bool = false
    private(set) var loadedContent: String = ""
    var lastError: String?

    private var repositoryPath: String = ""

    func load(repositoryPath: String) {
        self.repositoryPath = repositoryPath
        let fm = FileManager.default

        files = ClaudeMdLevel.allCases.map { level in
            let path = Self.filePath(for: level, repositoryPath: repositoryPath)
            let exists = fm.fileExists(atPath: path)
            var content: String?
            var modifiedAt: Date?

            if exists {
                content = try? String(contentsOfFile: path, encoding: .utf8)
                modifiedAt = (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date
            }

            return ClaudeMdFile(
                id: level,
                level: level,
                path: path,
                exists: exists,
                content: content,
                modifiedAt: modifiedAt
            )
        }

        // selectedLevel を維持（リロード時）
        if let level = selectedLevel, let file = files.first(where: { $0.level == level }) {
            let content = file.content ?? ""
            loadedContent = content
            editorContent = content
            isDirty = false
        }
    }

    func select(_ level: ClaudeMdLevel) {
        if selectedLevel == level {
            // 再選択で編集画面を非表示
            selectedLevel = nil
            loadedContent = ""
            editorContent = ""
            isDirty = false
            return
        }
        selectedLevel = level
        let content: String
        if let file = files.first(where: { $0.level == level }) {
            content = file.content ?? ""
        } else {
            content = ""
        }
        loadedContent = content
        editorContent = content
        isDirty = false
    }

    func save() {
        guard let level = selectedLevel else { return }
        let path = Self.filePath(for: level, repositoryPath: repositoryPath)

        do {
            let directory = (path as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try editorContent.write(toFile: path, atomically: true, encoding: .utf8)
            isDirty = false
            lastError = nil
            // ファイル一覧を更新
            load(repositoryPath: repositoryPath)
        } catch {
            Logger.store.error("Failed to save \(path, privacy: .public): \(error)")
            lastError = "Failed to save \(level.rawValue): \(error.localizedDescription)"
        }
    }

    func reset() {
        files = []
        selectedLevel = nil
        loadedContent = ""
        editorContent = ""
        isDirty = false
        repositoryPath = ""
    }

    func createFile(at level: ClaudeMdLevel) {
        let path = Self.filePath(for: level, repositoryPath: repositoryPath)
        do {
            let directory = (path as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try "".write(toFile: path, atomically: true, encoding: .utf8)
            lastError = nil
            load(repositoryPath: repositoryPath)
            select(level)
        } catch {
            Logger.store.error("Failed to create \(path, privacy: .public): \(error)")
            lastError = "Failed to create \(level.rawValue): \(error.localizedDescription)"
        }
    }

    // MARK: - Path Resolution

    static func filePath(for level: ClaudeMdLevel, repositoryPath: String) -> String {
        switch level {
        case .user:
            return (NSHomeDirectory() as NSString)
                .appendingPathComponent(".claude/CLAUDE.md")
        case .project:
            return (repositoryPath as NSString)
                .appendingPathComponent("CLAUDE.md")
        case .projectLocal:
            return (repositoryPath as NSString)
                .appendingPathComponent(".claude/CLAUDE.md")
        }
    }
}
