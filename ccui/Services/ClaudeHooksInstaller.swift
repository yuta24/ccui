import Foundation

final class ClaudeHooksInstaller {
    /// settings.local.json は read-modify-write なので、`WorktreeStore.load` の
    /// `withTaskGroup` で並行実行されるとユーザー定義 hooks を取り違えて上書きする。
    /// install 全体を直列化する。
    private static let installLock = NSLock()

    nonisolated static func install(worktreePath: String, socketPath: String = UDSListenerService.socketPath) throws {
        installLock.lock()
        defer { installLock.unlock() }

        let claudeDir = (worktreePath as NSString).appendingPathComponent(".claude")
        let settingsPath = (claudeDir as NSString).appendingPathComponent("settings.local.json")

        try FileManager.default.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)

        var settings: [String: Any] = [:]
        if let existingData = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
           let existingJSON = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
            settings = existingJSON
        }

        let escapedPath = socketPath.replacingOccurrences(of: "'", with: "'\\''")
        let hookCommand = "if [ -n \"$CCUI_SESSION\" ]; then cat | nc -U '\(escapedPath)' 2>/dev/null; fi; true"

        let ccuiEntry: [String: Any] = [
            "hooks": [["type": "command", "command": hookCommand] as [String: Any]]
        ]

        var existingHooks = settings["hooks"] as? [String: Any] ?? [:]
        for eventName in ["Stop", "Notification", "PreToolUse", "PostToolUse", "SubagentStop", "PermissionRequest", "UserPromptSubmit"] {
            var entries = existingHooks[eventName] as? [[String: Any]] ?? []
            // 既存の ccui エントリを除去してから追加（冪等性）
            entries.removeAll { entry in
                guard let hooks = entry["hooks"] as? [[String: Any]] else { return false }
                return hooks.contains { hook in
                    guard let cmd = hook["command"] as? String else { return false }
                    return cmd == hookCommand || cmd.contains("nc -U '\(escapedPath)'")
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
