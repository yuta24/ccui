import Foundation

enum AppearanceMode: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "システム"
        case .light: "ライト"
        case .dark: "ダーク"
        }
    }
}
