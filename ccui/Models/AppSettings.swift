import Foundation

struct AppSettings: Hashable, Sendable, Codable {
    var environmentVariables: [EnvironmentVariable]

    init(environmentVariables: [EnvironmentVariable] = []) {
        self.environmentVariables = environmentVariables
    }
}
