import Foundation
import Testing
@testable import ccui

/// `ClaudeEventPersistenceCoordinator` の actor 直列化を検証する。並行 save/remove
/// が同一インスタンス経由で発行された場合、内部の `JSONFileClaudeEventPersistence`
/// に対するアクセスが直列化され、最終的なディスク状態が一貫することを確認する。
struct ClaudeEventPersistenceCoordinatorTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccui-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    @Test func saveSessionRoundTrip() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = JSONFileClaudeEventPersistence(baseDirectory: dir)
        let coord = ClaudeEventPersistenceCoordinator(persistence: persistence)

        let session = TestHelpers.makeSession(id: "s1", worktreePath: "/repo")
        await coord.saveSession(session, worktreePath: "/repo", repositoryPath: "/repo")

        let loaded = try await coord.loadAll()
        #expect(loaded["/repo"]?["s1"] != nil)
    }

    @Test func removeSessionRemovesFile() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = JSONFileClaudeEventPersistence(baseDirectory: dir)
        let coord = ClaudeEventPersistenceCoordinator(persistence: persistence)

        let session = TestHelpers.makeSession(id: "s1", worktreePath: "/repo")
        await coord.saveSession(session, worktreePath: "/repo", repositoryPath: "/repo")
        await coord.removeSession("s1", worktreePath: "/repo")

        let loaded = try await coord.loadAll()
        #expect(loaded["/repo"]?["s1"] == nil)
    }

    @Test func removeWorktreeRemovesAllSessions() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = JSONFileClaudeEventPersistence(baseDirectory: dir)
        let coord = ClaudeEventPersistenceCoordinator(persistence: persistence)

        for i in 0..<3 {
            let session = TestHelpers.makeSession(id: "s\(i)", worktreePath: "/repo")
            await coord.saveSession(session, worktreePath: "/repo", repositoryPath: "/repo")
        }
        await coord.removeWorktree("/repo")

        let loaded = try await coord.loadAll()
        #expect(loaded["/repo"] == nil)
    }

    /// 大量の並行 save が直列化されてすべて永続化される。
    /// `Task.detached` で I/O を逃がしている実装が、内部の static lock により
    /// 競合を起こさないことを確認する。
    @Test func concurrentSavesAllPersisted() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = JSONFileClaudeEventPersistence(baseDirectory: dir)
        let coord = ClaudeEventPersistenceCoordinator(persistence: persistence)
        let sessionCount = 24

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<sessionCount {
                let session = TestHelpers.makeSession(id: "s\(i)", worktreePath: "/repo")
                group.addTask {
                    await coord.saveSession(session, worktreePath: "/repo", repositoryPath: "/repo")
                }
            }
        }

        let loaded = try await coord.loadAll()
        #expect(loaded["/repo"]?.count == sessionCount)
    }

    /// loadSessionsForRepository が 1 度の actor hop で sessions と worktreePaths を
    /// 取得し、書き込みとの間で観測する状態が一貫することを確認する。
    @Test func loadSessionsForRepositoryIsConsistent() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = JSONFileClaudeEventPersistence(baseDirectory: dir)
        let coord = ClaudeEventPersistenceCoordinator(persistence: persistence)

        // 同一リポジトリの 2 つの worktree
        await coord.saveSession(
            TestHelpers.makeSession(id: "s1", worktreePath: "/repo/wt-1"),
            worktreePath: "/repo/wt-1",
            repositoryPath: "/repo"
        )
        await coord.saveSession(
            TestHelpers.makeSession(id: "s2", worktreePath: "/repo/wt-2"),
            worktreePath: "/repo/wt-2",
            repositoryPath: "/repo"
        )
        // 別リポジトリ
        await coord.saveSession(
            TestHelpers.makeSession(id: "s3", worktreePath: "/other"),
            worktreePath: "/other",
            repositoryPath: "/other"
        )

        let result = try await coord.loadSessionsForRepository("/repo")

        // worktreePaths は要求した repository に紐づく worktree のみ
        #expect(result.worktreePaths == Set(["/repo/wt-1", "/repo/wt-2"]))

        // allSessions は他リポジトリも含まれる (一貫したスナップショット)
        #expect(result.allSessions["/repo/wt-1"]?["s1"] != nil)
        #expect(result.allSessions["/repo/wt-2"]?["s2"] != nil)
        #expect(result.allSessions["/other"]?["s3"] != nil)
    }

    /// pruneOldSessions が actor 経由でも正しく動作する
    @Test func pruneOldSessions() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = JSONFileClaudeEventPersistence(baseDirectory: dir)
        let coord = ClaudeEventPersistenceCoordinator(persistence: persistence)

        let now = Date()
        for i in 0..<5 {
            var session = TestHelpers.makeSession(id: "s\(i)", worktreePath: "/repo")
            session.append(
                TestHelpers.makeEvent(
                    sessionId: "s\(i)",
                    hookEventName: .stop,
                    receivedAt: now.addingTimeInterval(Double(i) * 60)
                ),
                maxEvents: 100
            )
            await coord.saveSession(session, worktreePath: "/repo", repositoryPath: "/repo")
        }

        await coord.pruneOldSessions(maxPerWorktree: 2)

        let loaded = try await coord.loadAll()
        #expect(loaded["/repo"]?.count == 2)
        // 最新の 2 件が残る
        #expect(loaded["/repo"]?["s4"] != nil)
        #expect(loaded["/repo"]?["s3"] != nil)
    }
}
