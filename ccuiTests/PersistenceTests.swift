import Foundation
import Testing
@testable import ccui

struct ClaudeEventPersistenceTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccui-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - directoryName

    @Test func directoryNameIsDeterministic() {
        let a = ClaudeEventPersistence.directoryName(for: "/repo/path")
        let b = ClaudeEventPersistence.directoryName(for: "/repo/path")
        #expect(a == b)
    }

    @Test func directoryNameDiffersForDifferentPaths() {
        let a = ClaudeEventPersistence.directoryName(for: "/repo/a")
        let b = ClaudeEventPersistence.directoryName(for: "/repo/b")
        #expect(a != b)
    }

    @Test func directoryNameIsHexString() {
        let name = ClaudeEventPersistence.directoryName(for: "/test")
        #expect(name.allSatisfy { $0.isHexDigit })
        #expect(name.count == 32) // 16 bytes * 2 hex chars
    }

    // MARK: - Save and Load

    @Test func saveAndLoadSession() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)
        let event = TestHelpers.makeEvent(sessionId: "s1", hookEventName: .preToolUse, toolName: "Bash")
        var session = TestHelpers.makeSession(id: "s1", worktreePath: "/repo")
        session.append(event, maxEvents: 100)

        await persistence.saveSession(session, worktreePath: "/repo", repositoryPath: "/repo")

        let loaded = try await persistence.loadAll()
        #expect(loaded.keys.contains("/repo"))
        #expect(loaded["/repo"]?["s1"] != nil)
        #expect(loaded["/repo"]?["s1"]?.events.count == 1)
    }

    @Test func loadAllFromEmptyDirectoryReturnsEmpty() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)
        let loaded = try await persistence.loadAll()
        #expect(loaded.isEmpty)
    }

    // MARK: - Remove Session

    @Test func removeSession() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)
        let session = TestHelpers.makeSession(id: "s1", worktreePath: "/repo")

        await persistence.saveSession(session, worktreePath: "/repo", repositoryPath: "/repo")
        await persistence.removeSession("s1", worktreePath: "/repo")

        let loaded = try await persistence.loadAll()
        #expect(loaded["/repo"]?["s1"] == nil)
    }

    // MARK: - Remove Worktree

    @Test func removeWorktree() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)
        let session = TestHelpers.makeSession(id: "s1", worktreePath: "/repo")

        await persistence.saveSession(session, worktreePath: "/repo", repositoryPath: "/repo")
        await persistence.removeWorktree("/repo")

        let loaded = try await persistence.loadAll()
        #expect(loaded["/repo"] == nil)
    }

    // MARK: - Prune Old Sessions

    @Test func pruneOldSessions() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)
        let now = Date()

        for i in 0..<5 {
            let sessionId = "s\(i)"
            let event = TestHelpers.makeEvent(
                sessionId: sessionId,
                hookEventName: .stop,
                receivedAt: now.addingTimeInterval(Double(i) * 60)
            )
            var session = TestHelpers.makeSession(id: sessionId, worktreePath: "/repo")
            session.append(event, maxEvents: 100)
            await persistence.saveSession(session, worktreePath: "/repo", repositoryPath: "/repo")
        }

        await persistence.pruneOldSessions(maxPerWorktree: 3)

        let loaded = try await persistence.loadAll()
        let sessions = loaded["/repo"] ?? [:]
        #expect(sessions.count == 3)
        // Newest sessions should remain
        #expect(sessions["s4"] != nil)
        #expect(sessions["s3"] != nil)
        #expect(sessions["s2"] != nil)
    }

    // MARK: - Repository Query

    @Test func worktreePathsForRepository() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)

        // 同一リポジトリに属する 2 つの worktree
        await persistence.saveSession(
            TestHelpers.makeSession(id: "s1", worktreePath: "/repo"),
            worktreePath: "/repo",
            repositoryPath: "/repo"
        )
        await persistence.saveSession(
            TestHelpers.makeSession(id: "s2", worktreePath: "/repo-feature"),
            worktreePath: "/repo-feature",
            repositoryPath: "/repo"
        )
        // 別リポジトリ
        await persistence.saveSession(
            TestHelpers.makeSession(id: "s3", worktreePath: "/other"),
            worktreePath: "/other",
            repositoryPath: "/other"
        )

        let result = try await persistence.loadSessionsForRepository("/repo")
        #expect(result.worktreePaths == Set(["/repo", "/repo-feature"]))

        // allSessions は他リポジトリも含む一貫したスナップショット
        #expect(result.allSessions["/repo"]?["s1"] != nil)
        #expect(result.allSessions["/repo-feature"]?["s2"] != nil)
        #expect(result.allSessions["/other"]?["s3"] != nil)
    }

    @Test func worktreePathsForRepositoryExcludesNilEntries() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)

        // repositoryPath が nil のエントリ（マイグレーション直後の状態）
        await persistence.saveSession(
            TestHelpers.makeSession(id: "s1", worktreePath: "/legacy"),
            worktreePath: "/legacy",
            repositoryPath: nil
        )
        // repositoryPath が設定済みのエントリ
        await persistence.saveSession(
            TestHelpers.makeSession(id: "s2", worktreePath: "/repo"),
            worktreePath: "/repo",
            repositoryPath: "/repo"
        )

        let result = try await persistence.loadSessionsForRepository("/repo")
        // nil エントリは他リポジトリのデータ汚染を防ぐため含めない
        #expect(!result.worktreePaths.contains("/legacy"))
        #expect(result.worktreePaths.contains("/repo"))
    }

    @Test func worktreePathsForRepositoryWithNoMatch() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)
        let result = try await persistence.loadSessionsForRepository("/nonexistent")
        #expect(result.worktreePaths.isEmpty)
    }

    @Test func multipleWorktrees() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)

        await persistence.saveSession(
            TestHelpers.makeSession(id: "s1", worktreePath: "/repo1"),
            worktreePath: "/repo1",
            repositoryPath: "/repo1"
        )
        await persistence.saveSession(
            TestHelpers.makeSession(id: "s2", worktreePath: "/repo2"),
            worktreePath: "/repo2",
            repositoryPath: "/repo2"
        )

        let loaded = try await persistence.loadAll()
        #expect(loaded.keys.count == 2)
        #expect(loaded["/repo1"]?["s1"] != nil)
        #expect(loaded["/repo2"]?["s2"] != nil)
    }
}

// MARK: - JSONFileRepositoryPersistence Tests

struct JSONFileRepositoryPersistenceTests {

    @Test func saveAndLoadRepositories() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccui-test-\(UUID().uuidString)")
            .appendingPathComponent("repos.json")
        defer { try? FileManager.default.removeItem(at: tempFile.deletingLastPathComponent()) }

        let persistence = JSONFileRepositoryPersistence(fileURL: tempFile)

        let repos = [
            Repository(name: "repo1", path: "/path/repo1"),
            Repository(name: "repo2", path: "/path/repo2"),
        ]
        try persistence.save(repos)

        let loaded = try persistence.load()
        #expect(loaded.count == 2)
        #expect(loaded[0].name == "repo1")
        #expect(loaded[1].name == "repo2")
    }

    @Test func loadFromNonexistentFileReturnsEmpty() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).json")
        let persistence = JSONFileRepositoryPersistence(fileURL: tempFile)
        let loaded = try persistence.load()
        #expect(loaded.isEmpty)
    }

    /// 直前の atomic 書き込み失敗等で 0 byte ファイルが残っているケース。
    /// 初回起動相当として扱い、空配列を返す（decode エラーで throw しない）。
    @Test func loadFromZeroByteFileReturnsEmpty() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccui-test-\(UUID().uuidString)")
            .appendingPathComponent("repos.json")
        try FileManager.default.createDirectory(at: tempFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempFile.deletingLastPathComponent()) }
        try Data().write(to: tempFile)

        let persistence = JSONFileRepositoryPersistence(fileURL: tempFile)
        let loaded = try persistence.load()
        #expect(loaded.isEmpty)
    }

    /// 非空だが decode 不能なファイルは破損とみなし throw する。
    @Test func loadFromCorruptFileThrows() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccui-test-\(UUID().uuidString)")
            .appendingPathComponent("repos.json")
        try FileManager.default.createDirectory(at: tempFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempFile.deletingLastPathComponent()) }
        try Data("not json".utf8).write(to: tempFile)

        let persistence = JSONFileRepositoryPersistence(fileURL: tempFile)
        #expect(throws: (any Error).self) {
            try persistence.load()
        }
    }
}

// MARK: - JSONFileAppSettingsPersistence Tests

struct JSONFileAppSettingsPersistenceTests {

    @Test func saveAndLoadSettings() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccui-test-\(UUID().uuidString)")
            .appendingPathComponent("settings.json")
        defer { try? FileManager.default.removeItem(at: tempFile.deletingLastPathComponent()) }

        let persistence = JSONFileAppSettingsPersistence(fileURL: tempFile)
        let settings = AppSettings(environmentVariables: [EnvironmentVariable(key: "FOO", value: "bar")])
        try persistence.save(settings)

        let loaded = try persistence.load()
        #expect(loaded == settings)
    }

    @Test func loadFromNonexistentFileReturnsDefault() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).json")
        let persistence = JSONFileAppSettingsPersistence(fileURL: tempFile)
        let loaded = try persistence.load()
        #expect(loaded == AppSettings())
    }

    /// 直前の atomic 書き込み失敗等で 0 byte ファイルが残っているケース。
    /// 初回起動相当として扱い、デフォルト設定を返す（decode エラーで throw しない）。
    @Test func loadFromZeroByteFileReturnsDefault() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccui-test-\(UUID().uuidString)")
            .appendingPathComponent("settings.json")
        try FileManager.default.createDirectory(at: tempFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempFile.deletingLastPathComponent()) }
        try Data().write(to: tempFile)

        let persistence = JSONFileAppSettingsPersistence(fileURL: tempFile)
        let loaded = try persistence.load()
        #expect(loaded == AppSettings())
    }

    /// 非空だが decode 不能なファイルは破損とみなし throw する。
    @Test func loadFromCorruptFileThrows() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccui-test-\(UUID().uuidString)")
            .appendingPathComponent("settings.json")
        try FileManager.default.createDirectory(at: tempFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempFile.deletingLastPathComponent()) }
        try Data("not json".utf8).write(to: tempFile)

        let persistence = JSONFileAppSettingsPersistence(fileURL: tempFile)
        #expect(throws: (any Error).self) {
            try persistence.load()
        }
    }
}

// MARK: - JSONFileWorktreeSessionPersistence Tests

struct JSONFileWorktreeSessionPersistenceTests {

    @Test func saveAndLoadEntries() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccui-test-\(UUID().uuidString)")
            .appendingPathComponent("worktree-sessions.json")
        defer { try? FileManager.default.removeItem(at: tempFile.deletingLastPathComponent()) }

        let persistence = JSONFileWorktreeSessionPersistence(fileURL: tempFile)
        let entries = [
            "/repo": [WorktreeSessionEntry(sessionId: "s1", createdAt: Date(), title: "Task")],
        ]
        try persistence.save(entries)

        let loaded = try persistence.load()
        #expect(loaded["/repo"]?.first?.sessionId == "s1")
    }

    @Test func loadFromNonexistentFileReturnsEmpty() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).json")
        let persistence = JSONFileWorktreeSessionPersistence(fileURL: tempFile)
        let loaded = try persistence.load()
        #expect(loaded.isEmpty)
    }

    /// 直前の atomic 書き込み失敗等で 0 byte ファイルが残っているケース。
    /// 初回起動相当として扱い、空辞書を返す（decode エラーで throw しない）。
    /// これにより、直後の createSession 等で空状態が誤って永続化され、
    /// 既存のセッション履歴が失われることを防ぐ。
    @Test func loadFromZeroByteFileReturnsEmpty() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccui-test-\(UUID().uuidString)")
            .appendingPathComponent("worktree-sessions.json")
        try FileManager.default.createDirectory(at: tempFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempFile.deletingLastPathComponent()) }
        try Data().write(to: tempFile)

        let persistence = JSONFileWorktreeSessionPersistence(fileURL: tempFile)
        let loaded = try persistence.load()
        #expect(loaded.isEmpty)
    }

    /// 非空だが decode 不能なファイルは破損とみなし throw する。
    @Test func loadFromCorruptFileThrows() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccui-test-\(UUID().uuidString)")
            .appendingPathComponent("worktree-sessions.json")
        try FileManager.default.createDirectory(at: tempFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempFile.deletingLastPathComponent()) }
        try Data("not json".utf8).write(to: tempFile)

        let persistence = JSONFileWorktreeSessionPersistence(fileURL: tempFile)
        #expect(throws: (any Error).self) {
            try persistence.load()
        }
    }
}
