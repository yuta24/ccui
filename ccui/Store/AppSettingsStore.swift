import AppKit
import Foundation
import OSLog
import SwiftUI

@Observable
@MainActor
final class AppSettingsStore {
    private(set) var settings: AppSettings
    private let persistence: any AppSettingsPersistence
    var onFontChanged: (() -> Void)?

    init(persistence: any AppSettingsPersistence) {
        do {
            settings = try persistence.load()
        } catch {
            Logger.store.error("Failed to load app settings: \(error)")
            settings = AppSettings()
        }
        self.persistence = persistence
        if !Self.availableMonospacedFonts.contains(settings.fontName) {
            settings.fontName = AppSettings.defaultFontName
        }
        if !Self.availableShells.contains(settings.shellPath) {
            settings.shellPath = AppSettings.defaultShellPath
        }
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

    var fontName: String {
        get { settings.fontName }
        set {
            settings.fontName = newValue
            persist()
            onFontChanged?()
        }
    }

    var fontSize: Double {
        get { settings.fontSize }
        set {
            settings.fontSize = min(max(newValue, AppSettings.minFontSize), AppSettings.maxFontSize)
            persist()
            onFontChanged?()
        }
    }

    var shellPath: String {
        get { settings.shellPath }
        set {
            settings.shellPath = newValue
            persist()
        }
    }

    var notificationsEnabled: Bool {
        get { settings.notificationsEnabled }
        set {
            settings.notificationsEnabled = newValue
            persist()
        }
    }

    var notificationSoundEnabled: Bool {
        get { settings.notificationSoundEnabled }
        set {
            settings.notificationSoundEnabled = newValue
            persist()
        }
    }

    var resolvedNSFont: NSFont {
        NSFontManager.shared.font(withFamily: fontName, traits: .fixedPitchFontMask, weight: 5, size: CGFloat(fontSize))
            ?? NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
    }

    var resolvedFont: Font {
        Font.custom(fontName, size: fontSize)
    }

    nonisolated static let availableShells: [String] = {
        guard let contents = try? String(contentsOfFile: "/etc/shells", encoding: .utf8) else {
            return ["/bin/zsh", "/bin/bash"]
        }
        return contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: $0) }
    }()

    nonisolated static let availableMonospacedFonts: [String] = {
        NSFontManager.shared
            .availableFontNames(with: .fixedPitchFontMask)?
            .compactMap { name -> String? in
                guard let font = NSFont(name: name, size: 12) else { return nil }
                return font.familyName
            }
            .reduce(into: [String]()) { result, family in
                if !result.contains(family) { result.append(family) }
            } ?? []
    }()

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
