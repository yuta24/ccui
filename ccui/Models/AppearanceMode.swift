import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
