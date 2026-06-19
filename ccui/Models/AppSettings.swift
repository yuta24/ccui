import Foundation

struct AppSettings: Hashable, Sendable, Codable {
    static let defaultFontName = "Menlo"
    static let defaultFontSize: Double = 12
    static let minFontSize: Double = 8
    static let maxFontSize: Double = 32
    static let defaultShellPath = "/bin/zsh"

    var environmentVariables: [EnvironmentVariable]
    var appearanceMode: AppearanceMode
    var fontName: String
    var fontSize: Double
    var shellPath: String
    var notificationsEnabled: Bool
    var notificationSoundEnabled: Bool

    init(
        environmentVariables: [EnvironmentVariable] = [],
        appearanceMode: AppearanceMode = .system,
        fontName: String = AppSettings.defaultFontName,
        fontSize: Double = AppSettings.defaultFontSize,
        shellPath: String = AppSettings.defaultShellPath,
        notificationsEnabled: Bool = true,
        notificationSoundEnabled: Bool = true
    ) {
        self.environmentVariables = environmentVariables
        self.appearanceMode = appearanceMode
        self.fontName = fontName
        self.fontSize = fontSize
        self.shellPath = shellPath
        self.notificationsEnabled = notificationsEnabled
        self.notificationSoundEnabled = notificationSoundEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        environmentVariables = try container.decode([EnvironmentVariable].self, forKey: .environmentVariables)
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? AppSettings.defaultFontName
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? AppSettings.defaultFontSize
        shellPath = try container.decodeIfPresent(String.self, forKey: .shellPath) ?? AppSettings.defaultShellPath
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        notificationSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationSoundEnabled) ?? true
    }
}
