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

    init(rootPath: String) {
        self.rootPath = rootPath
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        expandedIDs = []
        loadingIDs = []

        let path = rootPath
        do {
            let (index, result) = try await Task.detached(priority: .userInitiated) {
                let index = GitFileIndex.build(repositoryPath: path)
                let nodes = try Self.scanDirectory(at: path, rootPath: path, fileIndex: index)
                return (index, nodes)
            }.value
            fileIndex = index
            nodes = result
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func expand(_ node: FileNode) {
        expandedIDs.insert(node.id)
        if node.isDirectory && !node.isLoaded {
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

    private nonisolated static func scanDirectory(at path: String, rootPath: String, fileIndex: GitFileIndex?) throws -> [FileNode] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(atPath: path)

        var folders: [FileNode] = []
        var files: [FileNode] = []

        for name in contents where !name.hasPrefix(".") {
            let fullPath = (path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

            let ignoreStatus: GitIgnoreStatus
            if let fileIndex {
                if isDir.boolValue {
                    ignoreStatus = fileIndex.isIgnoredDirectory(fullPath) ? .ignored : .visible
                } else {
                    ignoreStatus = fileIndex.isIgnored(fullPath) ? .ignored : .visible
                }
            } else {
                ignoreStatus = .visible
            }

            if isDir.boolValue {
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
