import CryptoKit
import Foundation
import OSLog

protocol ClaudeEventPersistence: Sendable {
    func loadAll() throws -> [String: [String: AgentSession]]
    func saveSession(_ session: AgentSession, worktreePath: String) throws
    func removeSession(_ sessionId: String, worktreePath: String) throws
    func removeWorktree(_ worktreePath: String) throws
    /// ワークツリーごとのディスク上セッション数を maxPerWorktree 以下に削減する
    func pruneOldSessions(maxPerWorktree: Int) throws
}

struct JSONFileClaudeEventPersistence: ClaudeEventPersistence {
    private let baseDirectory: URL

    init(baseDirectory: URL = JSONFileClaudeEventPersistence.defaultBaseDirectory) {
        self.baseDirectory = baseDirectory
    }

    func loadAll() throws -> [String: [String: AgentSession]] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: baseDirectory.path) else { return [:] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // index.json にワークツリーパス → ハッシュのマッピングを保持
        let indexURL = baseDirectory.appendingPathComponent("index.json")
        guard fm.fileExists(atPath: indexURL.path) else { return [:] }
        let indexData = try Data(contentsOf: indexURL)
        let index = try JSONDecoder().decode([String: String].self, from: indexData)

        var result: [String: [String: AgentSession]] = [:]

        for (worktreePath, dirName) in index {
            let worktreeDir = baseDirectory.appendingPathComponent(dirName)
            guard fm.fileExists(atPath: worktreeDir.path) else { continue }

            let files = try fm.contentsOfDirectory(atPath: worktreeDir.path)
            var sessions: [String: AgentSession] = [:]

            for file in files where file.hasSuffix(".json") {
                let fileURL = worktreeDir.appendingPathComponent(file)
                do {
                    let data = try Data(contentsOf: fileURL)
                    let session = try decoder.decode(AgentSession.self, from: data)
                    sessions[session.id] = session
                } catch {
                    Logger.persistence.warning("Skipping corrupt file \(file, privacy: .public): \(error)")
                }
            }

            if !sessions.isEmpty {
                result[worktreePath] = sessions
            }
        }

        return result
    }

    func saveSession(_ session: AgentSession, worktreePath: String) throws {
        let fm = FileManager.default
        let dirName = Self.directoryName(for: worktreePath)
        let worktreeDir = baseDirectory.appendingPathComponent(dirName)

        try fm.createDirectory(at: worktreeDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        let fileURL = worktreeDir.appendingPathComponent("\(session.id).json")
        try data.write(to: fileURL, options: .atomic)

        // index を更新
        try updateIndex(worktreePath: worktreePath, dirName: dirName)
    }

    func removeSession(_ sessionId: String, worktreePath: String) throws {
        let dirName = Self.directoryName(for: worktreePath)
        let fileURL = baseDirectory
            .appendingPathComponent(dirName)
            .appendingPathComponent("\(sessionId).json")
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            try fm.removeItem(at: fileURL)
        }
    }

    func removeWorktree(_ worktreePath: String) throws {
        let fm = FileManager.default
        let dirName = Self.directoryName(for: worktreePath)
        let worktreeDir = baseDirectory.appendingPathComponent(dirName)

        if fm.fileExists(atPath: worktreeDir.path) {
            try fm.removeItem(at: worktreeDir)
        }

        // index から削除
        let indexURL = baseDirectory.appendingPathComponent("index.json")
        if fm.fileExists(atPath: indexURL.path) {
            let data = try Data(contentsOf: indexURL)
            var index = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
            index.removeValue(forKey: worktreePath)
            let newData = try JSONEncoder().encode(index)
            try newData.write(to: indexURL, options: .atomic)
        }
    }

    func pruneOldSessions(maxPerWorktree: Int) throws {
        let fm = FileManager.default
        let indexURL = baseDirectory.appendingPathComponent("index.json")
        guard fm.fileExists(atPath: indexURL.path) else { return }

        let indexData = try Data(contentsOf: indexURL)
        let index = try JSONDecoder().decode([String: String].self, from: indexData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for (_, dirName) in index {
            let worktreeDir = baseDirectory.appendingPathComponent(dirName)
            guard fm.fileExists(atPath: worktreeDir.path) else { continue }

            let files = try fm.contentsOfDirectory(atPath: worktreeDir.path)
                .filter { $0.hasSuffix(".json") }
            guard files.count > maxPerWorktree else { continue }

            // 各ファイルの最終イベント日時を取得し、古い順にソート（デコード不可のファイルは最古扱い）
            var entries: [(file: String, lastEvent: Date)] = []
            for file in files {
                let fileURL = worktreeDir.appendingPathComponent(file)
                if let data = try? Data(contentsOf: fileURL),
                   let session = try? decoder.decode(AgentSession.self, from: data) {
                    entries.append((file, session.lastEventAt ?? .distantPast))
                } else {
                    entries.append((file, .distantPast))
                }
            }
            entries.sort { $0.lastEvent < $1.lastEvent }

            let toRemove = entries.count - maxPerWorktree
            for entry in entries.prefix(toRemove) {
                let fileURL = worktreeDir.appendingPathComponent(entry.file)
                try? fm.removeItem(at: fileURL)
                Logger.persistence.info("Pruned old session file: \(entry.file, privacy: .public)")
            }
        }
    }

    // MARK: - Private

    private func updateIndex(worktreePath: String, dirName: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        let indexURL = baseDirectory.appendingPathComponent("index.json")
        var index: [String: String] = [:]
        if fm.fileExists(atPath: indexURL.path) {
            let data = try Data(contentsOf: indexURL)
            index = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }

        if index[worktreePath] != dirName {
            index[worktreePath] = dirName
            let data = try JSONEncoder().encode(index)
            try data.write(to: indexURL, options: .atomic)
        }
    }

    static func directoryName(for worktreePath: String) -> String {
        let hash = SHA256.hash(data: Data(worktreePath.utf8))
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private static var defaultBaseDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return appSupport
            .appendingPathComponent("ccui")
            .appendingPathComponent("claude-events")
    }
}
