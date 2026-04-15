import Foundation
import Testing
@testable import ccui

struct JSONFileClaudeEventPersistenceTests {

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
        let a = JSONFileClaudeEventPersistence.directoryName(for: "/repo/path")
        let b = JSONFileClaudeEventPersistence.directoryName(for: "/repo/path")
        #expect(a == b)
    }

    @Test func directoryNameDiffersForDifferentPaths() {
        let a = JSONFileClaudeEventPersistence.directoryName(for: "/repo/a")
        let b = JSONFileClaudeEventPersistence.directoryName(for: "/repo/b")
        #expect(a != b)
    }

    @Test func directoryNameIsHexString() {
        let name = JSONFileClaudeEventPersistence.directoryName(for: "/test")
        #expect(name.allSatisfy { $0.isHexDigit })
        #expect(name.count == 32) // 16 bytes * 2 hex chars
    }

    // MARK: - Save and Load

    @Test func saveAndLoadSession() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = JSONFileClaudeEventPersistence(baseDirectory: dir)
        let event = TestHelpers.makeEvent(sessionId: "s1", hookEventName: .preToolUse, toolName: "Bash")
        var session = TestHelpers.makeSession(id: "s1", worktreePath: "/repo")
        session.append(event, maxEvents: 100)

        try persistence.saveSession(session, worktreePath: "/repo")

        let loaded = try persistence.loadAll()
        #expect(loaded.keys.contains("/repo"))
        #expect(loaded["/repo"]?["s1"] != nil)
        #expect(loaded["/repo"]?["s1"]?.events.count == 1)
    }

    @Test func loadAllFromEmptyDirectoryReturnsEmpty() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = JSONFileClaudeEventPersistence(baseDirectory: dir)
        let loaded = try persistence.loadAll()
        #expect(loaded.isEmpty)
    }

    // MARK: - Remove Session

    @Test func removeSession() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = JSONFileClaudeEventPersistence(baseDirectory: dir)
        let session = TestHelpers.makeSession(id: "s1", worktreePath: "/repo")

        try persistence.saveSession(session, worktreePath: "/repo")
        try persistence.removeSession("s1", worktreePath: "/repo")

        let loaded = try persistence.loadAll()
        #expect(loaded["/repo"]?["s1"] == nil)
    }

    // MARK: - Remove Worktree

    @Test func removeWorktree() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = JSONFileClaudeEventPersistence(baseDirectory: dir)
        let session = TestHelpers.makeSession(id: "s1", worktreePath: "/repo")

        try persistence.saveSession(session, worktreePath: "/repo")
        try persistence.removeWorktree("/repo")

        let loaded = try persistence.loadAll()
        #expect(loaded["/repo"] == nil)
    }

    // MARK: - Prune Old Sessions

    @Test func pruneOldSessions() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = JSONFileClaudeEventPersistence(baseDirectory: dir)
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
            try persistence.saveSession(session, worktreePath: "/repo")
        }

        try persistence.pruneOldSessions(maxPerWorktree: 3)

        let loaded = try persistence.loadAll()
        let sessions = loaded["/repo"] ?? [:]
        #expect(sessions.count == 3)
        // Newest sessions should remain
        #expect(sessions["s4"] != nil)
        #expect(sessions["s3"] != nil)
        #expect(sessions["s2"] != nil)
    }

    // MARK: - Multiple Worktrees

    @Test func multipleWorktrees() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = JSONFileClaudeEventPersistence(baseDirectory: dir)

        try persistence.saveSession(
            TestHelpers.makeSession(id: "s1", worktreePath: "/repo1"),
            worktreePath: "/repo1"
        )
        try persistence.saveSession(
            TestHelpers.makeSession(id: "s2", worktreePath: "/repo2"),
            worktreePath: "/repo2"
        )

        let loaded = try persistence.loadAll()
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
}
