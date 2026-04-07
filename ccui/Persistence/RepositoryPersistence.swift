import Foundation

protocol RepositoryPersistence: Sendable {
    func load() throws -> [Repository]
    func save(_ repositories: [Repository]) throws
}
