import Foundation

struct Repository: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let name: String
    let path: String

    init(id: UUID = UUID(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}
