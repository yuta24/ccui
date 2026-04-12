import Foundation

protocol ClaudeEventPersistence: Sendable {
    func load() throws -> [String: [String: AgentSession]]
    func save(_ sessions: [String: [String: AgentSession]]) throws
}

struct JSONFileClaudeEventPersistence: ClaudeEventPersistence {
    private let fileURL: URL

    init(fileURL: URL = JSONFileClaudeEventPersistence.defaultFileURL) {
        self.fileURL = fileURL
    }

    func load() throws -> [String: [String: AgentSession]] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([String: [String: AgentSession]].self, from: data)
    }

    func save(_ sessions: [String: [String: AgentSession]]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sessions)
        try data.write(to: fileURL, options: .atomic)
    }

    private static var defaultFileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return appSupport
            .appendingPathComponent("ccui")
            .appendingPathComponent("claude-events.json")
    }
}
