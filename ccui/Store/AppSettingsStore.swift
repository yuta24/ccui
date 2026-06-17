import AppKit
import Foundation
import OSLog

@Observable
@MainActor
final class AppSettingsStore {
    private(set) var settings: AppSettings
    private let persistence: any AppSettingsPersistence

    init(persistence: any AppSettingsPersistence) {
        do {
            settings = try persistence.load()
        } catch {
            Logger.store.error("Failed to load app settings: \(error)")
            settings = AppSettings()
        }
        self.persistence = persistence
        applyAppearance(settings.appearanceMode)
    }

    var environmentVariables: [EnvironmentVariable] {
        get { settings.environmentVariables }
        set {
            settings.environmentVariables = newValue
            persist()
        }
    }

    var appearanceMode: AppearanceMode {
        get { settings.appearanceMode }
        set {
            settings.appearanceMode = newValue
            applyAppearance(newValue)
            persist()
        }
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func addVariable() {
        settings.environmentVariables.append(EnvironmentVariable())
        persist()
    }

    func removeVariable(id: UUID) {
        settings.environmentVariables.removeAll { $0.id == id }
        persist()
    }

    func resolvedEnvironmentStrings() -> [String] {
        settings.environmentVariables
            .filter { !$0.key.isEmpty }
            .map { "\($0.key)=\($0.value)" }
    }

    func persist() {
        do {
            try persistence.save(settings)
        } catch {
            Logger.store.error("Failed to persist app settings: \(error)")
        }
    }
}
