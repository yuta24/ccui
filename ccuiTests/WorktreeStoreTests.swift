import Foundation
import Testing
@testable import ccui

/// `WorktreeStore` の load/add/remove/loadBranches を実 git リポジトリ (一時ディレクトリ) を使って検証する。
@MainActor
struct WorktreeStoreTests {

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
        let path = (base as NSString).appendingPathComponent("ccui-worktreestore-tests-" + UUID().uuidString)
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

    private static func commitAll(_ message: String, at dir: String) {
        runGit(["add", "-A"], at: dir)
        runGit(["commit", "-q", "-m", message], at: dir)
    }

    // MARK: - load

    @Test func loadParsesMainAndAddedWorktrees() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        let store = WorktreeStore(repository: Repository(name: "test", path: repo), eventBus: AppEventBus())
        await store.load()

        #expect(store.errorMessage == nil)
        #expect(store.worktrees.count == 1)
        #expect(store.worktrees[0].isMain == true)
        #expect(store.worktrees[0].branch == "main")

        let worktreePath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ccui-worktreestore-wt-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(atPath: worktreePath) }
        Self.runGit(["worktree", "add", "-b", "feature", worktreePath], at: repo)

        await store.load()
        #expect(store.worktrees.count == 2)
        let added = store.worktrees.first { !$0.isMain }
        #expect(added?.branch == "feature")
    }

    @Test func loadSetsErrorMessageForInvalidRepository() async throws {
        let dir = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let store = WorktreeStore(repository: Repository(name: "test", path: dir), eventBus: AppEventBus())
        await store.load()

        #expect(store.errorMessage != nil)
        #expect(store.worktrees.isEmpty)
    }

    // MARK: - add / remove

    @Test func addCreatesNewWorktreeAndReloads() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        let store = WorktreeStore(repository: Repository(name: "test", path: repo), eventBus: AppEventBus())
        await store.load()
        #expect(store.worktrees.count == 1)

        let worktreePath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ccui-worktreestore-wt-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(atPath: worktreePath) }

        try await store.add(branch: "feature", path: worktreePath, createBranch: true)

        #expect(store.worktrees.count == 2)
        #expect(store.worktrees.contains { $0.branch == "feature" })
    }

    @Test func removeDeletesWorktree() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        let store = WorktreeStore(repository: Repository(name: "test", path: repo), eventBus: AppEventBus())
        await store.load()

        let worktreePath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ccui-worktreestore-wt-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(atPath: worktreePath) }
        try await store.add(branch: "feature", path: worktreePath, createBranch: true)
        #expect(store.worktrees.count == 2)

        let added = try #require(store.worktrees.first { $0.branch == "feature" })
        try await store.remove(added)

        #expect(store.worktrees.count == 1)
        #expect(!store.worktrees.contains { $0.branch == "feature" })
    }

    @Test func removeThrowsForDirtyWorktreeWithoutForce() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        let store = WorktreeStore(repository: Repository(name: "test", path: repo), eventBus: AppEventBus())
        await store.load()

        let worktreePath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ccui-worktreestore-wt-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(atPath: worktreePath) }
        try await store.add(branch: "feature", path: worktreePath, createBranch: true)

        let added = try #require(store.worktrees.first { $0.branch == "feature" })
        // 未コミットの変更を作って dirty にする
        Self.writeFile("dirty.txt", to: added.path)

        await #expect(throws: GitError.self) {
            try await store.remove(added)
        }
    }

    // MARK: - loadBranches

    @Test func loadBranchesReturnsLocalBranchesAndDefault() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)
        Self.runGit(["branch", "feature"], at: repo)
        Self.runGit(["update-ref", "refs/remotes/origin/main", "main"], at: repo)
        Self.runGit(["symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main"], at: repo)

        let store = WorktreeStore(repository: Repository(name: "test", path: repo), eventBus: AppEventBus())
        await store.loadBranches()

        #expect(Set(store.branches) == ["main", "feature"])
        #expect(store.defaultBranch == "main")
    }
}
