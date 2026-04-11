import Foundation

struct WorktreeSessionEntry: Codable, Sendable {
    let sessionId: String
    let createdAt: Date
}

protocol WorktreeSessionPersistence: Sendable {
    func load() throws -> [String: [WorktreeSessionEntry]]
    func save(_ entries: [String: [WorktreeSessionEntry]]) throws
}

final class JSONFileWorktreeSessionPersistence: WorktreeSessionPersistence {
    private let fileURL: URL

    init(fileURL: URL = JSONFileWorktreeSessionPersistence.defaultFileURL) {
        self.fileURL = fileURL
    }

    func load() throws -> [String: [WorktreeSessionEntry]] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([String: [WorktreeSessionEntry]].self, from: data)
    }

    func save(_ entries: [String: [WorktreeSessionEntry]]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: .atomic)
    }

    private static var defaultFileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return appSupport
            .appendingPathComponent("ccui")
            .appendingPathComponent("worktree-sessions.json")
    }
}
