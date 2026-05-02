import CryptoKit
import Foundation
import OSLog

protocol ClaudeEventPersistence: Sendable {
    func loadAll() throws -> [String: [String: AgentSession]]
    func saveSession(_ session: AgentSession, worktreePath: String, repositoryPath: String?) throws
    func removeSession(_ sessionId: String, worktreePath: String) throws
    func removeWorktree(_ worktreePath: String) throws
    /// ワークツリーごとのディスク上セッション数を maxPerWorktree 以下に削減する
    func pruneOldSessions(maxPerWorktree: Int) throws
    /// 指定リポジトリに属する全 worktree パスを返す（削除済み worktree を含む）
    func worktreePathsForRepository(_ repositoryPath: String) throws -> Set<String>
}

/// インデックスエントリ: worktree パスに対応するディレクトリ名とリポジトリパス
struct WorktreeIndexEntry: Codable, Sendable {
    let dirName: String
    let repositoryPath: String?
}

enum ClaudeEventPersistenceError: Error {
    /// index.json は存在するが decode 不能。空でないため破損とみなす。
    case corruptIndex
}

struct JSONFileClaudeEventPersistence: ClaudeEventPersistence {
    private let baseDirectory: URL

    /// index.json の read-modify-write を直列化する。
    /// 並行 saveSession 同士、および saveSession と removeWorktree の lost update を防ぐ。
    /// 同 baseDirectory を指す全インスタンスで共有する static lock。
    private static let indexLock = NSLock()

    init(baseDirectory: URL = JSONFileClaudeEventPersistence.defaultBaseDirectory) {
        self.baseDirectory = baseDirectory
    }

    func loadAll() throws -> [String: [String: AgentSession]] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: baseDirectory.path) else { return [:] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let index = try loadIndex()

        var result: [String: [String: AgentSession]] = [:]

        for (worktreePath, entry) in index {
            let worktreeDir = baseDirectory.appendingPathComponent(entry.dirName)
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

    func saveSession(_ session: AgentSession, worktreePath: String, repositoryPath: String?) throws {
        let fm = FileManager.default
        let dirName = Self.directoryName(for: worktreePath)
        let worktreeDir = baseDirectory.appendingPathComponent(dirName)

        try fm.createDirectory(at: worktreeDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        let fileURL = worktreeDir.appendingPathComponent("\(session.id).json")
        try data.write(to: fileURL, options: .atomic)

        // index は read-modify-write なので static lock で直列化する
        Self.indexLock.lock()
        defer { Self.indexLock.unlock() }
        try updateIndex(worktreePath: worktreePath, dirName: dirName, repositoryPath: repositoryPath)
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

        // index は read-modify-write なので static lock で直列化する。
        // index 更新を先に試行し、失敗したらディレクトリ削除も行わないことで
        // 「セッションファイル削除済みなのに index には残る」中途半端な状態を防ぐ。
        Self.indexLock.lock()
        defer { Self.indexLock.unlock() }
        let indexURL = baseDirectory.appendingPathComponent("index.json")
        if fm.fileExists(atPath: indexURL.path) {
            // 破損 index に対して空 dict を起点に書き戻すと残りエントリを全消失するため
            // try? で握りつぶさず throw を伝播させる
            var index = try loadIndex()
            index.removeValue(forKey: worktreePath)
            let newData = try JSONEncoder().encode(index)
            try newData.write(to: indexURL, options: .atomic)
        }

        if fm.fileExists(atPath: worktreeDir.path) {
            try fm.removeItem(at: worktreeDir)
        }
    }

    func pruneOldSessions(maxPerWorktree: Int) throws {
        let fm = FileManager.default
        let index = try loadIndex()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for (_, entry) in index {
            let worktreeDir = baseDirectory.appendingPathComponent(entry.dirName)
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

    func worktreePathsForRepository(_ repositoryPath: String) throws -> Set<String> {
        let index = try loadIndex()
        return Set(
            index.compactMap { worktreePath, entry in
                entry.repositoryPath == repositoryPath ? worktreePath : nil
            }
        )
    }

    // MARK: - Private

    /// インデックスを読み込む（旧フォーマット [String: String] からの自動マイグレーション対応）
    private func loadIndex() throws -> [String: WorktreeIndexEntry] {
        let fm = FileManager.default
        let indexURL = baseDirectory.appendingPathComponent("index.json")
        guard fm.fileExists(atPath: indexURL.path) else { return [:] }

        let data = try Data(contentsOf: indexURL)

        // 0 byte ファイル: 初回起動と同等扱い（直前の atomic 書き込み失敗等）
        if data.isEmpty { return [:] }

        // 新フォーマットを試行
        if let index = try? JSONDecoder().decode([String: WorktreeIndexEntry].self, from: data) {
            return index
        }

        // 旧フォーマット [String: String] からマイグレーション
        if let legacy = try? JSONDecoder().decode([String: String].self, from: data) {
            let migrated = legacy.mapValues { WorktreeIndexEntry(dirName: $0, repositoryPath: nil) }
            if let newData = try? JSONEncoder().encode(migrated) {
                try? newData.write(to: indexURL, options: .atomic)
            }
            return migrated
        }

        // ファイルは存在し非空だが decode 不能 = 破損。
        // 空 dict を返すと updateIndex が既存エントリを全消失させるため throw する。
        throw ClaudeEventPersistenceError.corruptIndex
    }

    /// 呼び出し前に `Self.indexLock` を取得していること。
    private func updateIndex(worktreePath: String, dirName: String, repositoryPath: String?) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        let indexURL = baseDirectory.appendingPathComponent("index.json")
        // 破損 index に空 dict を起点として書き戻さないよう、try? で握りつぶさず throw を伝播
        var index = try loadIndex()

        let existing = index[worktreePath]
        let effectiveRepoPath = repositoryPath ?? existing?.repositoryPath
        // dirName が変わった場合、または repositoryPath が nil → 非 nil に補完された場合に更新
        if existing?.dirName != dirName || existing?.repositoryPath != effectiveRepoPath {
            index[worktreePath] = WorktreeIndexEntry(dirName: dirName, repositoryPath: effectiveRepoPath)
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
