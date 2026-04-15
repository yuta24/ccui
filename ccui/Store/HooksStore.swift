import Foundation
import OSLog

@Observable
@MainActor
final class HooksStore {
    // MARK: - State

    private(set) var entries: [ClaudeHookPayload.HookEventName: [HookEntry]] = [:]
    private(set) var fireLogs: [HookFireLog] = []
    var selectedLevel: HookLevel = .worktree {
        didSet {
            entries = levelCache[selectedLevel] ?? [:]
            selectedEntryID = nil
        }
    }
    var selectedEventName: ClaudeHookPayload.HookEventName = .preToolUse {
        didSet { selectedEntryID = nil }
    }
    var selectedEntryID: UUID?
    private(set) var dirtyLevels: Set<HookLevel> = []

    var isDirty: Bool { !dirtyLevels.isEmpty }

    // MARK: - Internal

    private var worktreePath: String = ""
    /// Preserve full JSON per level so save doesn't destroy non-hooks keys
    private var rawSettings: [HookLevel: [String: Any]] = [:]
    /// Per-level in-memory entries (source of truth for edits)
    private var levelCache: [HookLevel: [ClaudeHookPayload.HookEventName: [HookEntry]]] = [:]

    static let allEvents: [ClaudeHookPayload.HookEventName] = [
        .preToolUse, .postToolUse, .stop, .notification,
        .subagentStop, .permissionRequest, .userPromptSubmit
    ]

    // MARK: - Lifecycle

    func load(worktreePath: String) async {
        self.worktreePath = worktreePath
        dirtyLevels = []
        let wp = worktreePath
        let loaded = await Task.detached(priority: .userInitiated) {
            var result: [HookLevel: [String: Any]] = [:]
            for level in HookLevel.allCases {
                result[level] = Self.readSettings(at: level.settingsPath(worktreePath: wp))
            }
            return result
        }.value
        for (level, json) in loaded {
            rawSettings[level] = json
            levelCache[level] = parseEntries(for: level)
        }
        entries = levelCache[selectedLevel] ?? [:]
    }

    func reset() {
        entries = [:]
        fireLogs = []
        selectedLevel = .worktree
        selectedEventName = .preToolUse
        selectedEntryID = nil
        dirtyLevels = []
        worktreePath = ""
        rawSettings = [:]
        levelCache = [:]
    }

    // MARK: - CRUD

    func addEntry() {
        let newEntry = HookEntry(hooks: [HookCommand()])
        modifyCurrentEvent { entries in
            entries.append(newEntry)
        }
        selectedEntryID = newEntry.id
    }

    func removeEntry(_ entry: HookEntry) {
        guard !entry.isManagedByCCUI else { return }
        modifyCurrentEvent { entries in
            entries.removeAll { $0.id == entry.id }
        }
        if selectedEntryID == entry.id {
            selectedEntryID = nil
        }
    }

    func updateMatcher(_ entry: HookEntry, matcher: String) {
        guard !entry.isManagedByCCUI else { return }
        modifyEntry(entry.id) { $0.matcher = matcher }
    }

    func updateCommand(_ command: HookCommand, newValue: String, in entry: HookEntry) {
        guard !entry.isManagedByCCUI else { return }
        modifyEntry(entry.id) { e in
            if let idx = e.hooks.firstIndex(where: { $0.id == command.id }) {
                e.hooks[idx].command = newValue
            }
        }
    }

    func addCommand(to entry: HookEntry) {
        guard !entry.isManagedByCCUI else { return }
        modifyEntry(entry.id) { $0.hooks.append(HookCommand()) }
    }

    func removeCommand(_ command: HookCommand, from entry: HookEntry) {
        guard !entry.isManagedByCCUI else { return }
        modifyEntry(entry.id) { e in
            e.hooks.removeAll { $0.id == command.id }
        }
    }

    // MARK: - Save

    func save() async {
        for level in HookLevel.allCases where dirtyLevels.contains(level) {
            await saveLevel(level)
        }
    }

    private func saveLevel(_ level: HookLevel) async {
        let path = level.settingsPath(worktreePath: worktreePath)
        var settings: [String: Any] = rawSettings[level] ?? [:]

        let levelEntries = levelCache[level] ?? [:]
        // Seed from existing hooks to preserve unknown event keys
        var hooksDict: [String: Any] = (settings["hooks"] as? [String: Any]) ?? [:]

        for event in Self.allEvents {
            let eventEntries = levelEntries[event] ?? []
            if eventEntries.isEmpty {
                hooksDict.removeValue(forKey: event.rawValue)
                continue
            }

            let rawEntries: [[String: Any]] = eventEntries.map { entry in
                var dict: [String: Any] = [:]
                if !entry.matcher.isEmpty {
                    dict["matcher"] = entry.matcher
                }
                dict["hooks"] = entry.hooks.map { cmd -> [String: Any] in
                    ["type": cmd.type, "command": cmd.command]
                }
                return dict
            }
            hooksDict[event.rawValue] = rawEntries
        }

        settings["hooks"] = hooksDict

        let result = await Task.detached(priority: .utility) { () -> Result<[String: Any], Error> in
            do {
                let directory = (path as NSString).deletingLastPathComponent
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
                return .success(Self.readSettings(at: path))
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let reloaded):
            dirtyLevels.remove(level)
            rawSettings[level] = reloaded
            levelCache[level] = parseEntries(for: level)
            entries = levelCache[selectedLevel] ?? [:]
        case .failure(let error):
            Logger.store.error("Failed to save hooks to \(path, privacy: .public): \(error)")
        }
    }

    // MARK: - Fire Log

    func updateFireLogs(events: [ClaudeEvent]) {
        let eventName = selectedEventName
        let logs = events
            .filter { $0.hookEventName == eventName }
            .sorted { $0.receivedAt > $1.receivedAt }
            .prefix(100)
            .map { HookFireLog(event: $0) }
        fireLogs = Array(logs)
    }

    // MARK: - Computed

    var currentEntries: [HookEntry] {
        entries[selectedEventName] ?? []
    }

    var selectedEntry: HookEntry? {
        guard let id = selectedEntryID else { return nil }
        return currentEntries.first { $0.id == id }
    }

    // MARK: - Private

    private nonisolated static func readSettings(at path: String) -> [String: Any] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private func loadLevel(_ level: HookLevel) {
        let path = level.settingsPath(worktreePath: worktreePath)
        rawSettings[level] = Self.readSettings(at: path)
    }

    private func parseEntries(for level: HookLevel) -> [ClaudeHookPayload.HookEventName: [HookEntry]] {
        let raw = rawSettings[level] ?? [:]
        guard let hooksDict = raw["hooks"] as? [String: Any] else {
            return Dictionary(uniqueKeysWithValues: Self.allEvents.map { ($0, [HookEntry]()) })
        }

        var result: [ClaudeHookPayload.HookEventName: [HookEntry]] = [:]
        for event in Self.allEvents {
            guard let rawEntries = hooksDict[event.rawValue] as? [[String: Any]] else {
                result[event] = []
                continue
            }
            result[event] = rawEntries.map { parseEntry($0) }
        }
        return result
    }

    private func parseEntry(_ raw: [String: Any]) -> HookEntry {
        let matcher = raw["matcher"] as? String ?? ""
        let managed = isCcuiManaged(raw)
        var commands: [HookCommand] = []

        if let rawHooks = raw["hooks"] as? [[String: Any]] {
            commands = rawHooks.map { hookDict in
                HookCommand(
                    type: hookDict["type"] as? String ?? "command",
                    command: hookDict["command"] as? String ?? ""
                )
            }
        }

        return HookEntry(matcher: matcher, hooks: commands, isManagedByCCUI: managed)
    }

    private func isCcuiManaged(_ rawEntry: [String: Any]) -> Bool {
        guard let hooks = rawEntry["hooks"] as? [[String: Any]] else { return false }
        return hooks.contains { hook in
            guard let cmd = hook["command"] as? String else { return false }
            return cmd.contains("nc -U") && cmd.contains("CCUI_SESSION")
        }
    }

    private func modifyCurrentEvent(_ mutation: (inout [HookEntry]) -> Void) {
        let level = selectedLevel
        let event = selectedEventName
        var cache = levelCache[level] ?? [:]
        var eventEntries = cache[event] ?? []
        mutation(&eventEntries)
        cache[event] = eventEntries
        levelCache[level] = cache
        entries = cache
        dirtyLevels.insert(level)
    }

    private func modifyEntry(_ id: UUID, mutation: (inout HookEntry) -> Void) {
        modifyCurrentEvent { entries in
            if let idx = entries.firstIndex(where: { $0.id == id }) {
                mutation(&entries[idx])
            }
        }
    }
}
