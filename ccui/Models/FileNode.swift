import Foundation

struct FileNode: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let path: String
    let isDirectory: Bool
    let children: [FileNode]
    let isLoaded: Bool

    init(id: UUID = UUID(), name: String, path: String, isDirectory: Bool, children: [FileNode] = [], isLoaded: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
        self.isLoaded = isDirectory ? isLoaded : true
    }

    func withChildren(_ children: [FileNode]) -> FileNode {
        FileNode(id: id, name: name, path: path, isDirectory: isDirectory, children: children, isLoaded: true)
    }
}
