import Foundation
import OSLog

@Observable
@MainActor
final class PermissionsStore {
    // MARK: - State

    private(set) var allowRules: [PermissionRule] = []
    private(set) var denyRules: [PermissionRule] = []
    private(set) var defaultMode: PermissionDefaultMode = .default
    private(set) var userDenyRules: [PermissionRule] = []
    private(set) var dirtyLevels: Set<PermissionLevel> = []

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

    var isDirty: Bool { !dirtyLevels.isEmpty }

    // MARK: - Internal

    private var worktreePath: String = ""
    private var rawSettings: [PermissionLevel: [String: Any]] = [:]
    private var levelCache: [PermissionLevel: LevelCache] = [:]

    private struct LevelCache {
        var allow: [PermissionRule]
        var deny: [PermissionRule]
        var defaultMode: PermissionDefaultMode
    }

    // MARK: - Lifecycle

    func load(worktreePath: String) async {
        self.worktreePath = worktreePath
        dirtyLevels = []
        let wp = worktreePath
        let loaded = await Task.detached(priority: .userInitiated) {
            var result: [PermissionLevel: [String: Any]] = [:]
            for level in PermissionLevel.allCases {
                result[level] = Self.readSettings(at: level.settingsPath(worktreePath: wp))
            }
            return result
        }.value
        for (level, json) in loaded {
            rawSettings[level] = json
            levelCache[level] = parseCache(for: level)
        }
        syncFromCache()
    }

    func reset() {
        worktreePath = ""
        rawSettings = [:]
        levelCache = [:]
        allowRules = []
        denyRules = []
        defaultMode = .default
        userDenyRules = []
        dirtyLevels = []
        selectedLevel = .worktree
        selectedListKind = .allow
        selectedRuleID = nil
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
        dirtyLevels.insert(level)
        syncFromCache()
    }

    // MARK: - Save

    func save() async {
        for level in PermissionLevel.allCases where dirtyLevels.contains(level) {
            await saveLevel(level)
        }
    }

    private func saveLevel(_ level: PermissionLevel) async {
        let path = level.settingsPath(worktreePath: worktreePath)
        var settings: [String: Any] = rawSettings[level] ?? [:]

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

        let success = await Task.detached(priority: .utility) { () -> Bool in
            do {
                let directory = (path as NSString).deletingLastPathComponent
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
                return true
            } catch {
                Logger.store.error("Failed to save permissions to \(path, privacy: .public): \(error)")
                return false
            }
        }.value

        if success {
            dirtyLevels.remove(level)
        }
    }

    // MARK: - Private

    private nonisolated static func readSettings(at path: String) -> [String: Any] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private func loadLevel(_ level: PermissionLevel) {
        let path = level.settingsPath(worktreePath: worktreePath)
        rawSettings[level] = Self.readSettings(at: path)
    }

    private func parseCache(for level: PermissionLevel) -> LevelCache {
        let raw = rawSettings[level] ?? [:]
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
        dirtyLevels.insert(level)
        syncFromCache()
    }
}
