import Foundation

/// `GitFileIndex.build()` の結果を `.git/index` の更新時刻でキャッシュする。
/// 同じリポジトリに対する複数 Store からの並行リクエストもまとめて 1 回の build で済ませる。
actor GitFileIndexCache {
    static let shared = GitFileIndexCache()

    private struct Entry {
        let index: GitFileIndex
        let indexFileMtime: Date?
    }

    private var entries: [String: Entry] = [:]
    private var inflight: [String: Task<GitFileIndex, Never>] = [:]

    func index(for repositoryPath: String) async -> GitFileIndex {
        let mtime = currentIndexMtime(at: repositoryPath)

        // mtime が両方 nil (`.git/index` 不在) のケースも「変化なし」と見なしてキャッシュヒット扱い。
        // そうしないと `git init` 直後など index が無い間ずっと再 build が走り続けてしまう。
        if let cached = entries[repositoryPath], cached.indexFileMtime == mtime {
            return cached.index
        }

        if let task = inflight[repositoryPath] {
            return await task.value
        }

        let task = Task<GitFileIndex, Never> {
            await GitFileIndex.build(repositoryPath: repositoryPath)
        }
        inflight[repositoryPath] = task

        let result = await task.value
        inflight.removeValue(forKey: repositoryPath)
        entries[repositoryPath] = Entry(index: result, indexFileMtime: mtime)
        return result
    }

    func invalidate(repositoryPath: String) {
        entries.removeValue(forKey: repositoryPath)
    }

    func clear() {
        entries.removeAll()
    }

    /// worktree の場合 `.git` はファイルで `gitdir: <path>` の中身が実際の git ディレクトリを指す。
    private nonisolated func currentIndexMtime(at repositoryPath: String) -> Date? {
        let dotGit = (repositoryPath as NSString).appendingPathComponent(".git")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dotGit, isDirectory: &isDir) else { return nil }

        let indexPath: String
        if isDir.boolValue {
            indexPath = (dotGit as NSString).appendingPathComponent("index")
        } else {
            guard let content = try? String(contentsOfFile: dotGit, encoding: .utf8) else { return nil }
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("gitdir: ") else { return nil }
            let gitDir = String(trimmed.dropFirst("gitdir: ".count))
            // `gitdir:` は絶対/相対どちらもありうる。相対の場合は `.git` ファイルのあるディレクトリ基準で解決する。
            let resolvedGitDir = (gitDir as NSString).isAbsolutePath
                ? gitDir
                : ((dotGit as NSString).deletingLastPathComponent as NSString).appendingPathComponent(gitDir)
            indexPath = (resolvedGitDir as NSString).appendingPathComponent("index")
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: indexPath)
        return attrs?[.modificationDate] as? Date
    }
}
