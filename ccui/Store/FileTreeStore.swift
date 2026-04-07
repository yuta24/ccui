import Foundation

@Observable
@MainActor
final class FileTreeStore {
    private(set) var nodes: [FileNode] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var expandedIDs: Set<FileNode.ID> = []
    private(set) var loadingIDs: Set<FileNode.ID> = []

    private let rootPath: String

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
            let result = try await Task.detached(priority: .userInitiated) {
                try Self.scanDirectory(at: path)
            }.value
            nodes = result
        } catch {
            print("[FileTreeStore] Failed to scan: \(error)")
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

    private func loadChildren(of node: FileNode) async {
        loadingIDs.insert(node.id)

        let path = node.path
        let children = await Task.detached(priority: .userInitiated) {
            (try? Self.scanDirectory(at: path)) ?? []
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
                return FileNode(id: node.id, name: node.name, path: node.path, isDirectory: true, children: updatedChildren, isLoaded: node.isLoaded)
            }
            return node
        }
    }

    private nonisolated static func scanDirectory(at path: String) throws -> [FileNode] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(atPath: path)

        var folders: [FileNode] = []
        var files: [FileNode] = []

        for name in contents {
            guard !name.hasPrefix(".") else { continue }

            let fullPath = (path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                folders.append(FileNode(name: name, path: fullPath, isDirectory: true))
            } else {
                files.append(FileNode(name: name, path: fullPath, isDirectory: false))
            }
        }

        folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return folders + files
    }
}
