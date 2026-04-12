import Foundation

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

    nonisolated static func build(repositoryPath: String) -> GitFileIndex {
        let nonIgnored = nonIgnoredFiles(at: repositoryPath)
        let (files, dirPrefixes) = ignoredFilesAndDirs(at: repositoryPath)
        return GitFileIndex(rootPath: repositoryPath, nonIgnoredPaths: nonIgnored, ignoredPaths: files, ignoredDirPrefixes: dirPrefixes)
    }

    /// Returns absolute paths of all tracked + untracked non-ignored files.
    private static func nonIgnoredFiles(at repositoryPath: String) -> Set<String> {
        let output: String
        do {
            output = try GitClient.lsFiles(["--cached", "--others", "--exclude-standard", "-z"], at: repositoryPath)
        } catch {
            return []
        }
        let rootPrefix = repositoryPath + "/"
        var paths = Set<String>()
        for rel in output.components(separatedBy: "\0") where !rel.isEmpty {
            paths.insert(rootPrefix + rel)
        }
        return paths
    }

    /// Returns ignored file paths and ignored directory prefixes (for ancestor matching).
    private static func ignoredFilesAndDirs(at repositoryPath: String) -> (files: Set<String>, dirPrefixes: [String]) {
        // First pass: get ignored directories efficiently
        let dirOutput: String
        do {
            dirOutput = try GitClient.lsFiles(["--others", "--ignored", "--exclude-standard", "--directory", "-z"], at: repositoryPath)
        } catch {
            return ([], [])
        }

        let rootPrefix = repositoryPath + "/"
        var paths = Set<String>()
        var dirPrefixes: [String] = []

        for rel in dirOutput.components(separatedBy: "\0") where !rel.isEmpty {
            if rel.hasSuffix("/") {
                let dirPath = rootPrefix + String(rel.dropLast())
                paths.insert(dirPath)
                dirPrefixes.append(dirPath + "/")
            } else {
                paths.insert(rootPrefix + rel)
            }
        }

        // Second pass: get individual ignored files not inside ignored directories
        // (e.g. *.log matched by pattern in a tracked directory)
        let fileOutput: String
        do {
            fileOutput = try GitClient.lsFiles(["--others", "--ignored", "--exclude-standard", "-z"], at: repositoryPath)
        } catch {
            return (paths, dirPrefixes)
        }

        for rel in fileOutput.components(separatedBy: "\0") where !rel.isEmpty {
            let absPath = rootPrefix + rel
            let alreadyCovered = dirPrefixes.contains { absPath.hasPrefix($0) }
            if !alreadyCovered {
                paths.insert(absPath)
            }
        }

        return (paths, dirPrefixes)
    }
}
