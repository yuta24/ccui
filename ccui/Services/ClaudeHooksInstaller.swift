import Foundation

@MainActor
final class ClaudeHooksInstaller {
    static func install(worktreePath: String, socketPath: String = UDSListenerService.socketPath) throws {
        let claudeDir = (worktreePath as NSString).appendingPathComponent(".claude")
        let settingsPath = (claudeDir as NSString).appendingPathComponent("settings.local.json")

        try FileManager.default.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)

        var settings: [String: Any] = [:]
        if let existingData = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
           let existingJSON = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
            settings = existingJSON
        }

        let escapedPath = socketPath.replacingOccurrences(of: "'", with: "'\\''")
        let hookCommand = "cat | nc -U '\(escapedPath)' 2>/dev/null; true"

        let ccuiEntry: [String: Any] = [
            "hooks": [["type": "command", "command": hookCommand] as [String: Any]]
        ]

        var existingHooks = settings["hooks"] as? [String: Any] ?? [:]
        for eventName in ["Stop", "Notification"] {
            var entries = existingHooks[eventName] as? [[String: Any]] ?? []
            // 既存の ccui エントリを除去してから追加（冪等性）
            entries.removeAll { entry in
                guard let hooks = entry["hooks"] as? [[String: Any]] else { return false }
                return hooks.contains { hook in
                    (hook["command"] as? String)?.contains("ccui.sock") == true
                }
            }
            entries.append(ccuiEntry)
            existingHooks[eventName] = entries
        }
        settings["hooks"] = existingHooks

        let jsonData = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: URL(fileURLWithPath: settingsPath), options: .atomic)
    }
}
