import Foundation

final class ClaudeHooksInstaller {
    /// settings.local.json は read-modify-write なので、`WorktreeStore.load` の
    /// `withTaskGroup` で並行実行されるとユーザー定義 hooks を取り違えて上書きする。
    /// install 全体を直列化する。
    private static let installLock = NSLock()

    /// ccui がワークツリーごとに自動生成するファイル。ユーザーの変更ではないため
    /// git のステータス表示 (status/diff/worktree remove の dirty 判定) から隠す。
    nonisolated private static let managedSettingsPath = ".claude/settings.local.json"

    nonisolated static func install(worktreePath: String, socketPath: String = UDSListenerService.socketPath) throws {
        installLock.lock()
        defer { installLock.unlock() }

        let claudeDir = (worktreePath as NSString).appendingPathComponent(".claude")
        let settingsPath = (claudeDir as NSString).appendingPathComponent("settings.local.json")

        try FileManager.default.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)
        excludeFromGitStatus(worktreePath: worktreePath)

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

    /// `.git/info/exclude` に `managedSettingsPath` を追記する。`.git/info/exclude` は
    /// 全ワークツリーが共有する common git dir 配下にあるため、一度書き込めば
    /// 他のワークツリーの status/diff/worktree remove にも反映される。
    /// すでにユーザーがこのパスをコミット済みの場合、gitignore/exclude は
    /// 追跡済みファイルに影響しないため、通常どおり変更が検出される。
    /// 書き込みに失敗してもフック導入自体は継続させるためエラーは無視する。
    nonisolated private static func excludeFromGitStatus(worktreePath: String) {
        guard let commonGitDir = commonGitDir(worktreePath: worktreePath) else { return }
        let infoDir = (commonGitDir as NSString).appendingPathComponent("info")
        let excludePath = (infoDir as NSString).appendingPathComponent("exclude")

        guard (try? FileManager.default.createDirectory(atPath: infoDir, withIntermediateDirectories: true)) != nil else { return }

        let existing = (try? String(contentsOfFile: excludePath, encoding: .utf8)) ?? ""
        guard !existing.components(separatedBy: .newlines).contains(managedSettingsPath) else { return }

        var updated = existing
        if !updated.isEmpty, !updated.hasSuffix("\n") {
            updated += "\n"
        }
        updated += managedSettingsPath + "\n"
        try? updated.write(toFile: excludePath, atomically: true, encoding: .utf8)
    }

    /// `worktreePath/.git` から共有 git ディレクトリ (objects/refs/info を含む) を解決する。
    /// メインワークツリーでは `.git` がそのディレクトリ自身、リンクされたワークツリーでは
    /// `.git` が `gitdir: <path>` を指すファイルで、`<path>/commondir` に共有ディレクトリへの
    /// 相対パスが書かれている。
    nonisolated private static func commonGitDir(worktreePath: String) -> String? {
        let gitPath = (worktreePath as NSString).appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory) else { return nil }
        if isDirectory.boolValue {
            return gitPath
        }

        guard let contents = try? String(contentsOfFile: gitPath, encoding: .utf8),
              let firstLine = contents.split(separator: "\n", maxSplits: 1).first,
              firstLine.hasPrefix("gitdir: ") else { return nil }
        let gitDir = String(firstLine.dropFirst("gitdir: ".count)).trimmingCharacters(in: .whitespaces)

        let commondirFile = (gitDir as NSString).appendingPathComponent("commondir")
        guard let commondirContents = try? String(contentsOfFile: commondirFile, encoding: .utf8) else { return nil }
        let relative = commondirContents.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = (relative as NSString).isAbsolutePath ? relative : (gitDir as NSString).appendingPathComponent(relative)
        return (resolved as NSString).standardizingPath
    }
}
