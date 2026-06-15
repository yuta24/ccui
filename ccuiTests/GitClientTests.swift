import Foundation
import Testing
@testable import ccui

/// `GitClient` の各 git ラッパー操作を実 git リポジトリ (一時ディレクトリ) を使って検証する。
struct GitClientTests {

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
        let path = (base as NSString).appendingPathComponent("ccui-gitclient-tests-" + UUID().uuidString)
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

    // MARK: - listWorktrees

    @Test func listWorktreesIncludesMainWorktree() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        let output = try await GitClient.listWorktrees(repositoryPath: repo)
        #expect(output.contains("branch refs/heads/main"))
        #expect(output.components(separatedBy: "\n").filter { $0.hasPrefix("worktree ") }.count == 1)
    }

    @Test func listWorktreesIncludesAddedWorktree() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        let worktreePath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ccui-gitclient-wt-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(atPath: worktreePath) }
        Self.runGit(["worktree", "add", "-b", "feature", worktreePath], at: repo)

        let output = try await GitClient.listWorktrees(repositoryPath: repo)
        #expect(output.contains("branch refs/heads/feature"))
        #expect(output.components(separatedBy: "\n").filter { $0.hasPrefix("worktree ") }.count == 2)
    }

    // MARK: - addWorktree / removeWorktree

    @Test func addAndRemoveWorktree() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        let worktreePath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ccui-gitclient-wt-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(atPath: worktreePath) }

        try await GitClient.addWorktree(args: ["-b", "feature", worktreePath], repositoryPath: repo)
        #expect(FileManager.default.fileExists(atPath: worktreePath))

        try await GitClient.removeWorktree(path: worktreePath, repositoryPath: repo)
        #expect(!FileManager.default.fileExists(atPath: worktreePath))
    }

    // MARK: - listLocalBranches

    @Test func listLocalBranchesReturnsAllBranches() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)
        Self.runGit(["branch", "feature"], at: repo)

        let branches = try await GitClient.listLocalBranches(repositoryPath: repo)
        #expect(Set(branches) == ["main", "feature"])
    }

    // MARK: - defaultBranch

    @Test func defaultBranchResolvesFromOriginHEAD() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)
        Self.runGit(["update-ref", "refs/remotes/origin/main", "main"], at: repo)
        Self.runGit(["symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main"], at: repo)

        let branch = try await GitClient.defaultBranch(repositoryPath: repo)
        #expect(branch == "main")
    }

    @Test func defaultBranchThrowsWhenOriginHEADMissing() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        await #expect(throws: GitError.self) {
            _ = try await GitClient.defaultBranch(repositoryPath: repo)
        }
    }

    // MARK: - statusCount

    @Test func statusCountIsZeroForCleanRepo() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        let count = try await GitClient.statusCount(worktreePath: repo)
        #expect(count == 0)
    }

    @Test func statusCountReflectsUntrackedAndModifiedFiles() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        Self.writeFile("a.txt", to: repo, contents: "modified")
        Self.writeFile("b.txt", to: repo)

        let count = try await GitClient.statusCount(worktreePath: repo)
        #expect(count == 2)
    }

    @Test func statusCountIgnoresClaudeSettingsLocal() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        try FileManager.default.createDirectory(atPath: (repo as NSString).appendingPathComponent(".claude"), withIntermediateDirectories: true)
        Self.writeFile(".claude/settings.local.json", to: repo, contents: "{}")

        let count = try await GitClient.statusCount(worktreePath: repo)
        #expect(count == 0)
    }

    // MARK: - lsFiles

    @Test func lsFilesListsTrackedFiles() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.writeFile("b.txt", to: repo)
        Self.commitAll("init", at: repo)

        let output = try await GitClient.lsFiles([], at: repo)
        let files = Set(output.components(separatedBy: "\n").filter { !$0.isEmpty })
        #expect(files == ["a.txt", "b.txt"])
    }

    // MARK: - diff

    @Test func diffIsEmptyForRepoWithoutCommits() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)

        let output = try await GitClient.diff(repositoryPath: repo)
        #expect(output.isEmpty)
    }

    @Test func diffShowsModifiedContent() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo, contents: "line1\n")
        Self.commitAll("init", at: repo)

        Self.writeFile("a.txt", to: repo, contents: "line1\nline2\n")

        let output = try await GitClient.diff(repositoryPath: repo)
        #expect(output.contains("a.txt"))
        #expect(output.contains("+line2"))
    }

    // MARK: - untrackedFiles

    @Test func untrackedFilesListsNewFiles() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        Self.writeFile("b.txt", to: repo)
        Self.writeFile("c.txt", to: repo)

        let files = try await GitClient.untrackedFiles(repositoryPath: repo)
        #expect(Set(files) == ["b.txt", "c.txt"])
    }

    @Test func untrackedFilesEmptyForCleanRepo() async throws {
        let repo = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: repo) }
        Self.initRepo(at: repo)
        Self.writeFile("a.txt", to: repo)
        Self.commitAll("init", at: repo)

        let files = try await GitClient.untrackedFiles(repositoryPath: repo)
        #expect(files.isEmpty)
    }

    // MARK: - Error handling

    @Test func commandFailedForNonGitDirectory() async throws {
        let dir = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        await #expect(throws: GitError.self) {
            _ = try await GitClient.lsFiles([], at: dir)
        }
    }
}
