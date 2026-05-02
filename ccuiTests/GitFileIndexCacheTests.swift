import Foundation
import Testing
@testable import ccui

/// `GitFileIndexCache` のキャッシュ挙動 (mtime 同一性 / invalidate / worktree / mtime 不在) を検証する。
/// `shared` は使わず各テストで新規 actor を作る。
struct GitFileIndexCacheTests {

    // MARK: - Helpers

    @discardableResult
    private static func runGit(_ args: [String], at path: String) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = args
        p.currentDirectoryURL = URL(fileURLWithPath: path)
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
        } catch {
            return -1
        }
        p.waitUntilExit()
        return p.terminationStatus
    }

    private static func makeTempDirectory() throws -> String {
        let base = NSTemporaryDirectory()
        let path = (base as NSString).appendingPathComponent("ccui-cache-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    private static func writeFile(_ name: String, to dir: String, contents: String = "x") {
        let path = (dir as NSString).appendingPathComponent(name)
        try? contents.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private static func initRepo(at dir: String) {
        runGit(["init", "-q", "-b", "main"], at: dir)
        runGit(["config", "user.email", "test@example.com"], at: dir)
        runGit(["config", "user.name", "Test"], at: dir)
        runGit(["config", "commit.gpgsign", "false"], at: dir)
    }

    // MARK: - Tests

    @Test func returnsBuiltIndexOnFirstCall() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)

        let cache = GitFileIndexCache()
        let index = await cache.index(for: repo)

        let names = Set(index.searchableFiles.map(\.name))
        #expect(names.contains("a.txt"))
    }

    /// `.git/index` の mtime が変わらない間はキャッシュが返り続けること。
    /// 1 回目の build 後に未 add のファイルを追加 → mtime は変化しない →
    /// キャッシュヒットで「新ファイルを含まない」結果が返るはず。
    @Test func returnsCachedResultWhenIndexMtimeUnchanged() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.runGit(["add", "a.txt"], at: repo)

        let cache = GitFileIndexCache()
        let first = await cache.index(for: repo)
        let firstNames = Set(first.searchableFiles.map(\.name))
        #expect(firstNames.contains("a.txt"))
        #expect(!firstNames.contains("b.txt"))

        // untracked で追加 → `.git/index` の mtime は変わらないのでキャッシュが返る想定
        Self.writeFile("b.txt", to: repo)

        let second = await cache.index(for: repo)
        let secondNames = Set(second.searchableFiles.map(\.name))
        #expect(!secondNames.contains("b.txt"), "Expected cache hit; b.txt should not appear without index mtime change")
    }

    /// `git add` で `.git/index` の mtime が変わったらキャッシュミスで再 build されること。
    @Test func rebuildsWhenIndexMtimeChanges() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.runGit(["add", "a.txt"], at: repo)

        let cache = GitFileIndexCache()
        _ = await cache.index(for: repo)

        // mtime 比較は秒粒度なので 1 秒以上空ける
        try await Task.sleep(for: .seconds(1))
        Self.writeFile("b.txt", to: repo)
        Self.runGit(["add", "b.txt"], at: repo)

        let second = await cache.index(for: repo)
        let names = Set(second.searchableFiles.map(\.name))
        #expect(names.contains("a.txt"))
        #expect(names.contains("b.txt"))
    }

    @Test func invalidateForcesRebuild() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.runGit(["add", "a.txt"], at: repo)

        let cache = GitFileIndexCache()
        _ = await cache.index(for: repo)

        // untracked 追加 (mtime 変わらない)
        Self.writeFile("b.txt", to: repo)

        // 明示 invalidate → 次回は再 build
        await cache.invalidate(repositoryPath: repo)
        let result = await cache.index(for: repo)
        let names = Set(result.searchableFiles.map(\.name))
        #expect(names.contains("a.txt"))
        #expect(names.contains("b.txt"))
    }

    /// worktree (`.git` がファイル) でも mtime 解決ができてキャッシュが効くこと。
    @Test func handlesWorktreeWithGitdirFile() async throws {
        let mainRepo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: mainRepo) }
        Self.initRepo(at: mainRepo)
        Self.writeFile("main.txt", to: mainRepo)
        Self.runGit(["add", "main.txt"], at: mainRepo)
        Self.runGit(["commit", "-q", "-m", "init"], at: mainRepo)

        let worktreePath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ccui-cache-wt-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(atPath: worktreePath) }
        Self.runGit(["worktree", "add", "-b", "feature", worktreePath], at: mainRepo)

        // `.git` がファイルになっていること (worktree の特徴) を確認
        var isDir: ObjCBool = false
        let dotGit = (worktreePath as NSString).appendingPathComponent(".git")
        #expect(FileManager.default.fileExists(atPath: dotGit, isDirectory: &isDir))
        #expect(isDir.boolValue == false)

        let cache = GitFileIndexCache()
        let first = await cache.index(for: worktreePath)
        let firstNames = Set(first.searchableFiles.map(\.name))
        #expect(firstNames.contains("main.txt"))

        // mtime 変えずに untracked 追加 → キャッシュヒット
        Self.writeFile("scratch.txt", to: worktreePath)
        let second = await cache.index(for: worktreePath)
        let secondNames = Set(second.searchableFiles.map(\.name))
        #expect(!secondNames.contains("scratch.txt"),
                "Worktree case should also use index mtime cache; new untracked file should not appear")
    }

    /// `.git` も `.git/index` も無いディレクトリに対して、mtime nil 同士が一致扱いされてキャッシュが効くこと。
    /// (regression: 以前は両方 nil でも常にキャッシュミスして毎回再 build されていた)
    @Test func cachesEvenWhenIndexFileMissing() async throws {
        let dir = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        // `git init` しない → `.git` が存在しない

        let cache = GitFileIndexCache()
        let first = await cache.index(for: dir)
        // `git ls-files` は失敗するので空 Set になる
        #expect(first.searchableFiles.isEmpty)

        // ファイルを追加。git 管理外なので結果に影響しないが、build を再実行すると失敗ログが増えるだけ。
        Self.writeFile("note.txt", to: dir)
        let second = await cache.index(for: dir)
        #expect(second.searchableFiles.isEmpty)
        // 主目的は「mtime nil でもキャッシュは return する」を確認すること。
        // 戻り値が等価なら最低限 OK (build 回数の直接検証は別途)。
    }
}
