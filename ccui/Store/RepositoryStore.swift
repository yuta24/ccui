import Foundation
import OSLog

@Observable
@MainActor
final class RepositoryStore {
    private(set) var repositories: [Repository] = []
    /// ディスク上に存在しないリポジトリパスのセット
    private(set) var missingPaths: Set<String> = []
    /// 直近のエラーメッセージ（UI 表示用）
    private(set) var lastError: String?
    private let persistence: any RepositoryPersistence

    init(persistence: any RepositoryPersistence) {
        self.persistence = persistence
        do {
            repositories = try persistence.load()
        } catch {
            Logger.store.error("Failed to load repositories: \(error)")
            repositories = []
            lastError = "Failed to load repositories: \(error.localizedDescription)"
        }
        refreshMissingPaths()
    }

    func exists(_ repository: Repository) -> Bool {
        !missingPaths.contains(repository.path)
    }

    func refreshMissingPaths() {
        let fm = FileManager.default
        missingPaths = Set(
            repositories
                .filter { !fm.fileExists(atPath: $0.path) }
                .map(\.path)
        )
    }

    func addRepository(at url: URL) {
        let name = url.lastPathComponent
        let path = url.path(percentEncoded: false)

        guard !repositories.contains(where: { $0.path == path }) else { return }

        let repo = Repository(name: name, path: path)
        repositories.append(repo)
        persist()
        refreshMissingPaths()
    }

    func remove(_ repository: Repository) {
        repositories.removeAll { $0.id == repository.id }
        missingPaths.remove(repository.path)
        persist()
    }

    func clearError() {
        lastError = nil
    }

    private func persist() {
        do {
            try persistence.save(repositories)
        } catch {
            Logger.store.error("Failed to persist repositories: \(error)")
            lastError = "Failed to save repositories: \(error.localizedDescription)"
        }
    }
}
