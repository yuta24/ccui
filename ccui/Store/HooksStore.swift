import Foundation

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

    var isDirty: Bool { settingsStore.isDirty }

    // MARK: - Internal

    private let settingsStore = LevelScopedSettingsStore<HookLevel>()
    /// Per-level in-memory entries (source of truth for edits)
    private var levelCache: [HookLevel: [ClaudeHookPayload.HookEventName: [HookEntry]]] = [:]

    static let allEvents: [ClaudeHookPayload.HookEventName] = [
        .preToolUse, .postToolUse, .stop, .notification,
        .subagentStop, .permissionRequest, .userPromptSubmit,
        .sessionStart, .messageDisplay
    ]

    // MARK: - Lifecycle

    func load(worktreePath: String) async {
        await settingsStore.load(worktreePath: worktreePath)
        for level in HookLevel.allCases {
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
        levelCache = [:]
        settingsStore.reset()
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
        let levelsToUpdate = settingsStore.dirtyLevels
        await settingsStore.save { [weak self] level, settings in
            self?.buildSettings(for: level, existing: settings) ?? settings
        }
        let succeededLevels = levelsToUpdate.subtracting(settingsStore.dirtyLevels)
        for level in succeededLevels {
            levelCache[level] = parseEntries(for: level)
        }
        entries = levelCache[selectedLevel] ?? [:]
    }

    private func buildSettings(for level: HookLevel, existing settings: [String: Any]) -> [String: Any] {
        var settings = settings
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
        return settings
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

    private func parseEntries(for level: HookLevel) -> [ClaudeHookPayload.HookEventName: [HookEntry]] {
        let raw = settingsStore.rawSettings[level] ?? [:]
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
        settingsStore.markDirty(level)
    }

    private func modifyEntry(_ id: UUID, mutation: (inout HookEntry) -> Void) {
        modifyCurrentEvent { entries in
            if let idx = entries.firstIndex(where: { $0.id == id }) {
                mutation(&entries[idx])
            }
        }
    }
}
