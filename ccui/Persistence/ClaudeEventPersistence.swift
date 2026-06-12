import CryptoKit
import Foundation
import OSLog

/// Claude イベント（セッション）のディスク永続化を担う actor。
/// 全ての I/O をこの actor 内で直列化することで、index.json への
/// 競合書き込みおよび読み取りの不整合を防ぐ。
/// `ClaudeEventStore`（書き込み主体）と `SessionAnalyticsStore`（読み取り）が
/// 同じインスタンスを共有することで、ファイルシステム上の整合性を担保する。
actor ClaudeEventPersistence {
    private let baseDirectory: URL

    init(baseDirectory: URL = ClaudeEventPersistence.defaultBaseDirectory) {
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

    /// 単一のディスクスナップショットから全セッションと repository に紐づく
    /// worktree パスを取得する。
    func loadSessionsForRepository(_ repositoryPath: String) throws
        -> (allSessions: [String: [String: AgentSession]], worktreePaths: Set<String>) {
        let allSessions = try loadAll()
        let worktreePaths = try worktreePathsForRepository(repositoryPath)
        return (allSessions, worktreePaths)
    }

    func saveSession(_ session: AgentSession, worktreePath: String, repositoryPath: String?) {
        do {
            let fm = FileManager.default
            let dirName = Self.directoryName(for: worktreePath)
            let worktreeDir = baseDirectory.appendingPathComponent(dirName)

            try fm.createDirectory(at: worktreeDir, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(session)
            let fileURL = worktreeDir.appendingPathComponent("\(session.id).json")
            try data.write(to: fileURL, options: .atomic)

            try updateIndex(worktreePath: worktreePath, dirName: dirName, repositoryPath: repositoryPath)
        } catch {
            Logger.persistence.error("Failed to persist session \(session.id): \(error)")
        }
    }

    func removeSession(_ sessionId: String, worktreePath: String) {
        do {
            let dirName = Self.directoryName(for: worktreePath)
            let fileURL = baseDirectory
                .appendingPathComponent(dirName)
                .appendingPathComponent("\(sessionId).json")
            let fm = FileManager.default
            if fm.fileExists(atPath: fileURL.path) {
                try fm.removeItem(at: fileURL)
            }
        } catch {
            Logger.persistence.error("Failed to remove session \(sessionId): \(error)")
        }
    }

    func removeWorktree(_ worktreePath: String) {
        do {
            let fm = FileManager.default
            let dirName = Self.directoryName(for: worktreePath)
            let worktreeDir = baseDirectory.appendingPathComponent(dirName)

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
        } catch {
            Logger.persistence.error("Failed to remove worktree \(worktreePath, privacy: .public): \(error)")
        }
    }

    /// ワークツリーごとのディスク上セッション数を maxPerWorktree 以下に削減する
    func pruneOldSessions(maxPerWorktree: Int) {
        do {
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
        } catch {
            Logger.persistence.error("Failed to prune old sessions: \(error)")
        }
    }

    // MARK: - Private

    /// 指定リポジトリに属する全 worktree パスを返す（削除済み worktree を含む）
    private func worktreePathsForRepository(_ repositoryPath: String) throws -> Set<String> {
        let index = try loadIndex()
        return Set(
            index.compactMap { worktreePath, entry in
                entry.repositoryPath == repositoryPath ? worktreePath : nil
            }
        )
    }

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

    nonisolated static func directoryName(for worktreePath: String) -> String {
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

/// インデックスエントリ: worktree パスに対応するディレクトリ名とリポジトリパス
struct WorktreeIndexEntry: Codable, Sendable {
    let dirName: String
    let repositoryPath: String?
}

enum ClaudeEventPersistenceError: Error {
    /// index.json は存在するが decode 不能。空でないため破損とみなす。
    case corruptIndex
}
