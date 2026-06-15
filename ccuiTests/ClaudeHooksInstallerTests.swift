import Foundation
import Testing
@testable import ccui

/// `ClaudeHooksInstaller.install` が `.claude/settings.local.json` を生成しつつ、
/// `.git/info/exclude` 経由で git のステータス表示から隠すことを検証する。
struct ClaudeHooksInstallerTests {

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
        let path = (base as NSString).appendingPathComponent("ccui-hooksinstaller-tests-" + UUID().uuidString)
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

    // MARK: - Tests

    @Test func installExcludesSettingsLocalFromStatus() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        try ClaudeHooksInstaller.install(worktreePath: repo)

        let settingsPath = (repo as NSString).appendingPathComponent(".claude/settings.local.json")
        #expect(FileManager.default.fileExists(atPath: settingsPath))

        let count = try await GitClient.statusCount(worktreePath: repo)
        #expect(count == 0)

        let untracked = try await GitClient.untrackedFiles(repositoryPath: repo)
        #expect(!untracked.contains(".claude/settings.local.json"))
    }

    @Test func installIsIdempotentForGitInfoExclude() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        try ClaudeHooksInstaller.install(worktreePath: repo)
        try ClaudeHooksInstaller.install(worktreePath: repo)

        let excludePath = (repo as NSString).appendingPathComponent(".git/info/exclude")
        let contents = try String(contentsOfFile: excludePath, encoding: .utf8)
        let occurrences = contents.components(separatedBy: .newlines).filter { $0 == ".claude/settings.local.json" }
        #expect(occurrences.count == 1)
    }

    @Test func installAppliesGitInfoExcludeAcrossLinkedWorktrees() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        let worktreePath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ccui-hooksinstaller-wt-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(atPath: worktreePath) }
        Self.runGit(["worktree", "add", "-q", "-b", "feature", worktreePath], at: repo)

        // 共有 git dir への書き込みはリンクされたワークツリー側から install しても反映される
        try ClaudeHooksInstaller.install(worktreePath: worktreePath)

        let excludePath = (repo as NSString).appendingPathComponent(".git/info/exclude")
        let contents = try String(contentsOfFile: excludePath, encoding: .utf8)
        #expect(contents.components(separatedBy: .newlines).contains(".claude/settings.local.json"))

        // メインワークツリーに同名ファイルがあっても、共有 exclude により dirty 扱いされない
        try FileManager.default.createDirectory(atPath: (repo as NSString).appendingPathComponent(".claude"), withIntermediateDirectories: true)
        Self.writeFile(".claude/settings.local.json", to: repo, contents: "{}")

        let count = try await GitClient.statusCount(worktreePath: repo)
        #expect(count == 0)
    }

    @Test func installDoesNotHideTrackedSettingsLocalModifications() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)

        // ユーザーが意図的に .claude/settings.local.json をコミットしているケース。
        // 開発者のグローバル gitignore でこのパスが無視されていても -f で強制的に追跡対象にする。
        try FileManager.default.createDirectory(atPath: (repo as NSString).appendingPathComponent(".claude"), withIntermediateDirectories: true)
        Self.writeFile(".claude/settings.local.json", to: repo, contents: "{\"v\":1}")
        Self.runGit(["add", "-f", "-A"], at: repo)
        Self.runGit(["commit", "-q", "-m", "init"], at: repo)

        try ClaudeHooksInstaller.install(worktreePath: repo)

        // install によるフック追記で settings.local.json 自体は変更されるため、
        // 追跡済みファイルへの変更として通常どおり検出される
        let count = try await GitClient.statusCount(worktreePath: repo)
        #expect(count > 0)
    }
}
