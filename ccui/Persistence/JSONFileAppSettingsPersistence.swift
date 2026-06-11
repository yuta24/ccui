import Foundation

final class JSONFileAppSettingsPersistence: AppSettingsPersistence {
    private let fileURL: URL

    init(fileURL: URL = JSONFileAppSettingsPersistence.defaultFileURL) {
        self.fileURL = fileURL
    }

    func load() throws -> AppSettings {
        guard let data = try PersistenceFile.readDataIfPresent(at: fileURL) else {
            return AppSettings()
        }
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }

    func save(_ settings: AppSettings) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }

    private static var defaultFileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return appSupport
            .appendingPathComponent("ccui")
            .appendingPathComponent("settings.json")
    }
}
