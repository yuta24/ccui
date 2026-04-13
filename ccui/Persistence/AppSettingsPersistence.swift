import Foundation

protocol AppSettingsPersistence: Sendable {
    func load() throws -> AppSettings
    func save(_ settings: AppSettings) throws
}
