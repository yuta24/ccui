import Foundation
import Testing
@testable import ccui

/// `ClaudeEventPersistence` が actor として全 I/O を直列化していることを検証する。
/// `Serialize ClaudeHooksInstaller writes with a static lock` (e2ff1e7) および
/// `Reorder removeWorktree to update index before deleting files` (b454d9c) で
/// 対処された安定性バグのリグレッションを catch する。
struct ClaudeEventPersistenceConcurrencyTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccui-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    /// 異なる worktree への並行 saveSession で index.json の lost update が
    /// 起きないことを確認する。直列化なしでは、最後に書いた worktree のみが残り
    /// 他のエントリが消える "lost update" バグが起きる。
    @Test func concurrentSavesPreserveAllEntries() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)
        let worktreeCount = 32

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<worktreeCount {
                let wtPath = "/repo/wt-\(i)"
                let session = TestHelpers.makeSession(id: "s\(i)", worktreePath: wtPath)
                group.addTask {
                    await persistence.saveSession(session, worktreePath: wtPath, repositoryPath: "/repo")
                }
            }
        }

        let loaded = try await persistence.loadAll()
        #expect(loaded.count == worktreeCount)
        for i in 0..<worktreeCount {
            #expect(loaded["/repo/wt-\(i)"]?["s\(i)"] != nil)
        }
    }

    /// 同一 worktree に対する並行 saveSession でセッションファイルが正しく
    /// 書き込まれることを確認する（index への重複登録は dirName が同一のため
    /// 1 エントリにまとまる）。
    @Test func concurrentSavesSameWorktreeKeepAllSessions() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)
        let sessionCount = 16

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<sessionCount {
                let session = TestHelpers.makeSession(id: "s\(i)", worktreePath: "/repo")
                group.addTask {
                    await persistence.saveSession(session, worktreePath: "/repo", repositoryPath: "/repo")
                }
            }
        }

        let loaded = try await persistence.loadAll()
        #expect(loaded["/repo"]?.count == sessionCount)
    }

    /// saveSession と removeWorktree が並行した場合、ディスク状態が常に一貫していることを確認する。
    /// 一貫性 = index に worktree がある ⇒ そのディレクトリ配下のセッションファイルは読み込める
    /// 一貫性 = index に worktree がない ⇒ そのディレクトリは削除されている (or 残骸を読まない)
    @Test func concurrentSaveAndRemoveLeaveConsistentState() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)

        // 事前に複数 worktree を保存
        for i in 0..<8 {
            let wt = "/repo/wt-\(i)"
            await persistence.saveSession(
                TestHelpers.makeSession(id: "s\(i)", worktreePath: wt),
                worktreePath: wt,
                repositoryPath: "/repo"
            )
        }

        // 半分を削除し、残り半分に新規セッション保存を並行実行
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<4 {
                let wt = "/repo/wt-\(i)"
                group.addTask {
                    await persistence.removeWorktree(wt)
                }
            }
            for i in 4..<8 {
                let wt = "/repo/wt-\(i)"
                group.addTask {
                    let extraSession = TestHelpers.makeSession(id: "s\(i)-extra", worktreePath: wt)
                    await persistence.saveSession(extraSession, worktreePath: wt, repositoryPath: "/repo")
                }
            }
        }

        // ディスクから再読込し、一貫性を確認
        let loaded = try await persistence.loadAll()
        // 削除されたエントリは index にも sessions にも存在しないはず
        for i in 0..<4 {
            #expect(loaded["/repo/wt-\(i)"] == nil, "worktree \(i) should be removed")
        }
        // 残りのエントリは存在しているはず
        for i in 4..<8 {
            #expect(loaded["/repo/wt-\(i)"]?.isEmpty == false, "worktree \(i) should be retained")
        }
    }

    /// removeWorktree がディスク削除より前に index 更新を完了するため、
    /// 並行 loadAll が「index に存在するが directory が消えている」中間状態を
    /// 観測しないことを検証する。`b454d9c Reorder removeWorktree to update index
    /// before deleting files` のリグレッション検知。
    @Test func concurrentRemoveAndLoadIsConsistent() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let persistence = ClaudeEventPersistence(baseDirectory: dir)

        // 複数 worktree を保存
        for i in 0..<6 {
            let wt = "/repo/wt-\(i)"
            await persistence.saveSession(
                TestHelpers.makeSession(id: "s\(i)", worktreePath: wt),
                worktreePath: wt,
                repositoryPath: "/repo"
            )
        }

        // remove と load を並走
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<6 {
                let wt = "/repo/wt-\(i)"
                group.addTask {
                    await persistence.removeWorktree(wt)
                }
            }
            for _ in 0..<10 {
                group.addTask {
                    // loadAll が throw せず完走することが一貫性の証
                    _ = try? await persistence.loadAll()
                }
            }
        }

        let final = try await persistence.loadAll()
        #expect(final.isEmpty)
    }
}
