import Foundation

nonisolated final class JSONFileRepositoryPersistence: RepositoryPersistence {
    private let fileURL: URL

    init(fileURL: URL = JSONFileRepositoryPersistence.defaultFileURL) {
        self.fileURL = fileURL
    }

    func load() throws -> [Repository] {
        guard let data = try PersistenceFile.readDataIfPresent(at: fileURL) else {
            return []
        }
        return try JSONDecoder().decode([Repository].self, from: data)
    }

    func save(_ repositories: [Repository]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(repositories)
        try data.write(to: fileURL, options: .atomic)
    }

    private static var defaultFileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return appSupport
            .appendingPathComponent("ccui")
            .appendingPathComponent("repositories.json")
    }
}
