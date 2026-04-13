import Foundation
import OSLog

@Observable
@MainActor
final class RepositoryStore {
    private(set) var repositories: [Repository] = []
    private let persistence: any RepositoryPersistence

    init(persistence: any RepositoryPersistence) {
        self.persistence = persistence
        do {
            repositories = try persistence.load()
        } catch {
            Logger.store.error("Failed to load repositories: \(error)")
            repositories = []
        }
    }

    func addRepository(at url: URL) {
        let name = url.lastPathComponent
        let path = url.path(percentEncoded: false)

        guard !repositories.contains(where: { $0.path == path }) else { return }

        let repo = Repository(name: name, path: path)
        repositories.append(repo)
        persist()
    }

    func remove(_ repository: Repository) {
        repositories.removeAll { $0.id == repository.id }
        persist()
    }

    private func persist() {
        do {
            try persistence.save(repositories)
        } catch {
            Logger.store.error("Failed to persist repositories: \(error)")
        }
    }
}
