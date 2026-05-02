import Foundation
import OSLog

nonisolated struct GitFileIndex: Sendable {
    let rootPath: String
    private let nonIgnoredPaths: Set<String>
    private let ignoredPaths: Set<String>
    private let ignoredDirPrefixes: [String]

    init(rootPath: String, nonIgnoredPaths: Set<String>, ignoredPaths: Set<String>, ignoredDirPrefixes: [String]) {
        self.rootPath = rootPath
        self.nonIgnoredPaths = nonIgnoredPaths
        self.ignoredPaths = ignoredPaths
        self.ignoredDirPrefixes = ignoredDirPrefixes
    }

    func isIgnored(_ absolutePath: String) -> Bool {
        if ignoredPaths.contains(absolutePath) { return true }
        return ignoredDirPrefixes.contains { absolutePath.hasPrefix($0) }
    }

    func isIgnoredDirectory(_ absolutePath: String) -> Bool {
        if ignoredPaths.contains(absolutePath) || ignoredPaths.contains(absolutePath + "/") { return true }
        return ignoredDirPrefixes.contains { (absolutePath + "/").hasPrefix($0) }
    }

    var searchableFiles: [FileNode] {
        nonIgnoredPaths.map { path in
            FileNode(name: (path as NSString).lastPathComponent, path: path, isDirectory: false)
        }
    }

    // MARK: - Build

    /// 3 回の `git ls-files` を並列実行して構築する。
    nonisolated static func build(repositoryPath: String) async -> GitFileIndex {
        async let nonIgnoredTask = Task.detached(priority: .userInitiated) {
            nonIgnoredFiles(at: repositoryPath)
        }.value
        async let ignoredDirsTask = Task.detached(priority: .userInitiated) {
            ignoredDirectories(at: repositoryPath)
        }.value
        async let ignoredFilesTask = Task.detached(priority: .userInitiated) {
            ignoredIndividualFiles(at: repositoryPath)
        }.value

        let nonIgnored = await nonIgnoredTask
        let (dirFiles, dirPrefixes) = await ignoredDirsTask
        let extraFiles = await ignoredFilesTask

        var files = dirFiles
        for path in extraFiles where !dirPrefixes.contains(where: { path.hasPrefix($0) }) {
            files.insert(path)
        }

        return GitFileIndex(
            rootPath: repositoryPath,
            nonIgnoredPaths: nonIgnored,
            ignoredPaths: files,
            ignoredDirPrefixes: dirPrefixes
        )
    }

    /// Returns absolute paths of all tracked + untracked non-ignored files.
    private static func nonIgnoredFiles(at repositoryPath: String) -> Set<String> {
        let output: String
        do {
            output = try GitClient.lsFiles(["--cached", "--others", "--exclude-standard", "-z"], at: repositoryPath)
        } catch {
            Logger.store.warning("GitFileIndex: ls-files (non-ignored) failed at \(repositoryPath, privacy: .public): \(error.localizedDescription)")
            return []
        }
        let rootPrefix = repositoryPath + "/"
        var paths = Set<String>()
        for rel in output.components(separatedBy: "\0") where !rel.isEmpty {
            paths.insert(rootPrefix + rel)
        }
        return paths
    }

    /// Returns ignored directories as both absolute paths and trailing-slash prefixes for ancestor matching.
    private static func ignoredDirectories(at repositoryPath: String) -> (files: Set<String>, dirPrefixes: [String]) {
        let output: String
        do {
            output = try GitClient.lsFiles(["--others", "--ignored", "--exclude-standard", "--directory", "-z"], at: repositoryPath)
        } catch {
            Logger.store.warning("GitFileIndex: ls-files (ignored dirs) failed at \(repositoryPath, privacy: .public): \(error.localizedDescription)")
            return ([], [])
        }

        let rootPrefix = repositoryPath + "/"
        var paths = Set<String>()
        var dirPrefixes: [String] = []

        for rel in output.components(separatedBy: "\0") where !rel.isEmpty {
            if rel.hasSuffix("/") {
                let dirPath = rootPrefix + String(rel.dropLast())
                paths.insert(dirPath)
                dirPrefixes.append(dirPath + "/")
            } else {
                paths.insert(rootPrefix + rel)
            }
        }

        return (paths, dirPrefixes)
    }

    /// Returns individually ignored files (e.g. *.log matched by pattern in a tracked directory).
    /// Caller is responsible for filtering out paths that fall under an ignored directory prefix.
    private static func ignoredIndividualFiles(at repositoryPath: String) -> Set<String> {
        let output: String
        do {
            output = try GitClient.lsFiles(["--others", "--ignored", "--exclude-standard", "-z"], at: repositoryPath)
        } catch {
            Logger.store.warning("GitFileIndex: ls-files (ignored files) failed at \(repositoryPath, privacy: .public): \(error.localizedDescription)")
            return []
        }

        let rootPrefix = repositoryPath + "/"
        var paths = Set<String>()
        for rel in output.components(separatedBy: "\0") where !rel.isEmpty {
            paths.insert(rootPrefix + rel)
        }
        return paths
    }
}
