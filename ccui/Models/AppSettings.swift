import Foundation

struct AppSettings: Hashable, Sendable, Codable {
    var environmentVariables: [EnvironmentVariable]
    var appearanceMode: AppearanceMode

    init(environmentVariables: [EnvironmentVariable] = [], appearanceMode: AppearanceMode = .system) {
        self.environmentVariables = environmentVariables
        self.appearanceMode = appearanceMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        environmentVariables = try container.decode([EnvironmentVariable].self, forKey: .environmentVariables)
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
    }
}
