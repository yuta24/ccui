import Foundation

@Observable
@MainActor
final class PermissionsStore {
    // MARK: - State

    private(set) var allowRules: [PermissionRule] = []
    private(set) var denyRules: [PermissionRule] = []
    private(set) var defaultMode: PermissionDefaultMode = .default
    private(set) var userDenyRules: [PermissionRule] = []

    var selectedLevel: PermissionLevel = .worktree {
        didSet {
            syncFromCache()
            selectedRuleID = nil
        }
    }
    var selectedListKind: PermissionListKind = .allow {
        didSet { selectedRuleID = nil }
    }
    var selectedRuleID: UUID?

    var isDirty: Bool { settingsStore.isDirty }

    // MARK: - Internal

    private let settingsStore = LevelScopedSettingsStore<PermissionLevel>()
    private var levelCache: [PermissionLevel: LevelCache] = [:]

    private struct LevelCache {
        var allow: [PermissionRule]
        var deny: [PermissionRule]
        var defaultMode: PermissionDefaultMode
    }

    // MARK: - Lifecycle

    func load(worktreePath: String) async {
        await settingsStore.load(worktreePath: worktreePath)
        for level in PermissionLevel.allCases {
            levelCache[level] = parseCache(for: level)
        }
        syncFromCache()
    }

    func reset() {
        levelCache = [:]
        allowRules = []
        denyRules = []
        defaultMode = .default
        userDenyRules = []
        selectedLevel = .worktree
        selectedListKind = .allow
        selectedRuleID = nil
        settingsStore.reset()
    }

    // MARK: - Computed

    var currentRules: [PermissionRule] {
        switch selectedListKind {
        case .allow: allowRules
        case .deny: denyRules
        }
    }

    // MARK: - CRUD

    func addRule() {
        let newRule = PermissionRule()
        modifyCurrentList { $0.append(newRule) }
        selectedRuleID = newRule.id
    }

    func removeRule(_ rule: PermissionRule) {
        modifyCurrentList { $0.removeAll { $0.id == rule.id } }
        if selectedRuleID == rule.id {
            selectedRuleID = nil
        }
    }

    func updateRule(_ rule: PermissionRule, value: String) {
        modifyCurrentList { list in
            if let idx = list.firstIndex(where: { $0.id == rule.id }) {
                list[idx].value = value
            }
        }
    }

    func setDefaultMode(_ mode: PermissionDefaultMode) {
        let level = selectedLevel
        var cache = levelCache[level] ?? LevelCache(allow: [], deny: [], defaultMode: .default)
        cache.defaultMode = mode
        levelCache[level] = cache
        settingsStore.markDirty(level)
        syncFromCache()
    }

    // MARK: - Save

    func save() async {
        let levelsToUpdate = settingsStore.dirtyLevels
        await settingsStore.save { [weak self] level, settings in
            self?.buildSettings(for: level, existing: settings) ?? settings
        }
        let succeededLevels = levelsToUpdate.subtracting(settingsStore.dirtyLevels)
        for level in succeededLevels {
            levelCache[level] = parseCache(for: level)
        }
        syncFromCache()
    }

    private func buildSettings(for level: PermissionLevel, existing settings: [String: Any]) -> [String: Any] {
        var settings = settings
        let cache = levelCache[level] ?? LevelCache(allow: [], deny: [], defaultMode: .default)

        // Seed from existing permissions to preserve unknown keys
        var permsDict: [String: Any] = (settings["permissions"] as? [String: Any]) ?? [:]

        let allowValues = cache.allow.map(\.value).filter { !$0.isEmpty }
        let denyValues = cache.deny.map(\.value).filter { !$0.isEmpty }

        if allowValues.isEmpty {
            permsDict.removeValue(forKey: "allow")
        } else {
            permsDict["allow"] = allowValues
        }

        if denyValues.isEmpty {
            permsDict.removeValue(forKey: "deny")
        } else {
            permsDict["deny"] = denyValues
        }

        if cache.defaultMode != .default {
            permsDict["defaultMode"] = cache.defaultMode.rawValue
        } else {
            permsDict.removeValue(forKey: "defaultMode")
        }

        settings["permissions"] = permsDict
        return settings
    }

    // MARK: - Private

    private func parseCache(for level: PermissionLevel) -> LevelCache {
        let raw = settingsStore.rawSettings[level] ?? [:]
        let permsDict = (raw["permissions"] as? [String: Any]) ?? [:]

        let allow = (permsDict["allow"] as? [String])?.map { PermissionRule(value: $0) } ?? []
        let deny = (permsDict["deny"] as? [String])?.map { PermissionRule(value: $0) } ?? []
        let modeStr = permsDict["defaultMode"] as? String ?? "default"
        let mode = PermissionDefaultMode(rawValue: modeStr) ?? .default

        return LevelCache(allow: allow, deny: deny, defaultMode: mode)
    }

    private func syncFromCache() {
        let cache = levelCache[selectedLevel] ?? LevelCache(allow: [], deny: [], defaultMode: .default)
        allowRules = cache.allow
        denyRules = cache.deny
        defaultMode = cache.defaultMode
        userDenyRules = levelCache[.user]?.deny ?? []
    }

    private func modifyCurrentList(_ mutation: (inout [PermissionRule]) -> Void) {
        let level = selectedLevel
        let kind = selectedListKind
        var cache = levelCache[level] ?? LevelCache(allow: [], deny: [], defaultMode: .default)

        switch kind {
        case .allow: mutation(&cache.allow)
        case .deny: mutation(&cache.deny)
        }

        levelCache[level] = cache
        settingsStore.markDirty(level)
        syncFromCache()
    }
}
