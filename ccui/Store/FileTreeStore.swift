import Foundation

@Observable
@MainActor
final class FileTreeStore {
    private(set) var nodes: [FileNode] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var expandedIDs: Set<FileNode.ID> = []
    private(set) var loadingIDs: Set<FileNode.ID> = []
    private(set) var selectedNode: FileNode?

    let rootPath: String
    private var fileIndex: GitFileIndex?
    private var loadTask: Task<Void, Never>?

    init(rootPath: String) {
        self.rootPath = rootPath
    }

    func load() async {
        loadTask?.cancel()

        isLoading = true
        errorMessage = nil
        expandedIDs = []
        loadingIDs = []

        let path = rootPath

        // Phase 1: Show file tree immediately without git status
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try Self.scanDirectory(at: path, rootPath: path, fileIndex: nil)
            }.value
            nodes = result
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false

        // Phase 2: Build git index in background, then re-apply ignore status
        loadTask = Task {
            let index = await GitFileIndexCache.shared.index(for: path)
            guard !Task.isCancelled else { return }
            fileIndex = index

            do {
                let updatedNodes = try await Task.detached(priority: .utility) {
                    try Self.scanDirectory(at: path, rootPath: path, fileIndex: index)
                }.value
                guard !Task.isCancelled else { return }
                // Preserve expanded state: only update top-level nodes
                nodes = Self.mergeIgnoreStatus(existing: nodes, updated: updatedNodes)
            } catch {
                // Ignore — tree is already displayed without git status
            }
        }
    }

    func expand(_ node: FileNode) {
        expandedIDs.insert(node.id)
        if node.isDirectory && !node.isLoaded && !loadingIDs.contains(node.id) {
            Task { await loadChildren(of: node) }
        }
    }

    func collapse(_ node: FileNode) {
        expandedIDs.remove(node.id)
    }

    func selectNode(_ node: FileNode) {
        guard !node.isDirectory else { return }
        selectedNode = node
    }

    private func loadChildren(of node: FileNode) async {
        loadingIDs.insert(node.id)

        let path = node.path
        let root = rootPath
        let idx = fileIndex
        let children = await Task.detached(priority: .userInitiated) {
            (try? Self.scanDirectory(at: path, rootPath: root, fileIndex: idx)) ?? []
        }.value

        let updated = node.withChildren(children)
        nodes = Self.replaceNode(in: nodes, targetID: node.id, with: updated)
        loadingIDs.remove(node.id)
    }

    private static func replaceNode(in nodes: [FileNode], targetID: FileNode.ID, with replacement: FileNode) -> [FileNode] {
        nodes.map { node in
            if node.id == targetID {
                return replacement
            } else if node.isDirectory && !node.children.isEmpty {
                let updatedChildren = replaceNode(in: node.children, targetID: targetID, with: replacement)
                return FileNode(id: node.id, name: node.name, path: node.path, isDirectory: true, children: updatedChildren, isLoaded: node.isLoaded, gitIgnoreStatus: node.gitIgnoreStatus)
            }
            return node
        }
    }

    /// Merge git ignore status from freshly scanned nodes into existing tree,
    /// preserving loaded children of expanded directories.
    private static func mergeIgnoreStatus(existing: [FileNode], updated: [FileNode]) -> [FileNode] {
        let updatedByPath = Dictionary(updated.map { ($0.path, $0) }, uniquingKeysWith: { _, last in last })
        return existing.map { node in
            guard let match = updatedByPath[node.path] else { return node }
            if node.isDirectory && node.isLoaded {
                // Keep loaded children, just update ignore status
                return FileNode(id: node.id, name: node.name, path: node.path, isDirectory: true, children: node.children, isLoaded: true, gitIgnoreStatus: match.gitIgnoreStatus)
            }
            return FileNode(id: node.id, name: node.name, path: node.path, isDirectory: node.isDirectory, children: node.children, isLoaded: node.isLoaded, gitIgnoreStatus: match.gitIgnoreStatus)
        }
    }

    private nonisolated static func scanDirectory(at path: String, rootPath: String, fileIndex: GitFileIndex?) throws -> [FileNode] {
        let fm = FileManager.default
        // `includingPropertiesForKeys: [.isDirectoryKey]` でディレクトリ判定をまとめて
        // prefetch し、エントリごとの追加 stat 呼び出し (fileExists) を避ける。
        let contents = try fm.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        var folders: [FileNode] = []
        var files: [FileNode] = []

        for url in contents {
            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard var isDirectory = resourceValues?.isDirectory else { continue }

            let name = url.lastPathComponent
            // `url.path` はディレクトリに末尾スラッシュを付与するため、
            // 既存の path 表現（末尾スラッシュなし）に合わせて再構築する。
            let fullPath = (path as NSString).appendingPathComponent(name)

            // シンボリックリンクの場合、`isDirectoryKey` はリンク自体の種別を返すため、
            // リンク先を解決する fileExists でディレクトリ判定する（旧実装と同じ挙動）。
            if resourceValues?.isSymbolicLink == true {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir) {
                    isDirectory = isDir.boolValue
                }
            }

            let ignoreStatus: GitIgnoreStatus
            if let fileIndex {
                if isDirectory {
                    ignoreStatus = fileIndex.isIgnoredDirectory(fullPath) ? .ignored : .visible
                } else {
                    ignoreStatus = fileIndex.isIgnored(fullPath) ? .ignored : .visible
                }
            } else {
                ignoreStatus = .visible
            }

            if isDirectory {
                folders.append(FileNode(name: name, path: fullPath, isDirectory: true, gitIgnoreStatus: ignoreStatus))
            } else {
                files.append(FileNode(name: name, path: fullPath, isDirectory: false, gitIgnoreStatus: ignoreStatus))
            }
        }

        folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return folders + files
    }
}
