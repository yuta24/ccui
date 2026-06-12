import Foundation
import OSLog

/// worktree-level / user-level のように、設定がレベル別の JSON ファイルへ
/// 分かれて保存される仕組みを表すプロトコル。
protocol SettingsLevel: CaseIterable, Hashable, Sendable {
    /// このレベルの設定ファイルパスを返す。
    nonisolated func settingsPath(worktreePath: String) -> String
}

/// レベル別 JSON 設定ファイルの読込・キャッシュ・dirty 管理・atomic 保存を担う汎用基盤。
/// `HooksStore`/`PermissionsStore` はそれぞれの `hooks`/`permissions` キー以下のみを
/// `build` クロージャで構築し、それ以外の未知キーは `rawSettings` 経由で保持される。
@MainActor
final class LevelScopedSettingsStore<Level: SettingsLevel> {
    /// レベルごとの生 JSON。対象キー以外の未知のキーを保持するために使う。
    private(set) var rawSettings: [Level: [String: Any]] = [:]
    private(set) var dirtyLevels: Set<Level> = []
    private var worktreePath: String = ""

    var isDirty: Bool { !dirtyLevels.isEmpty }

    /// 全レベルの設定ファイルを読み込み、`rawSettings` を更新して返す。
    @discardableResult
    func load(worktreePath: String) async -> [Level: [String: Any]] {
        self.worktreePath = worktreePath
        dirtyLevels = []
        let loaded = await Task.detached(priority: .userInitiated) {
            var result: [Level: [String: Any]] = [:]
            for level in Level.allCases {
                result[level] = Self.readSettings(at: level.settingsPath(worktreePath: worktreePath))
            }
            return result
        }.value
        rawSettings = loaded
        return loaded
    }

    func reset() {
        worktreePath = ""
        rawSettings = [:]
        dirtyLevels = []
    }

    func markDirty(_ level: Level) {
        dirtyLevels.insert(level)
    }

    /// dirty な各レベルについて `build(level, 既存rawSettings)` で更新後の設定 dict を構築し、
    /// atomic に書き込む。書き込み後はファイルを再読込して `rawSettings` を更新し、
    /// 該当レベルを `dirtyLevels` から取り除く。
    func save(build: (Level, [String: Any]) -> [String: Any]) async {
        for level in Level.allCases where dirtyLevels.contains(level) {
            let path = level.settingsPath(worktreePath: worktreePath)
            let settings = build(level, rawSettings[level] ?? [:])

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
                rawSettings[level] = reloaded
                dirtyLevels.remove(level)
            case .failure(let error):
                Logger.store.error("Failed to save settings to \(path, privacy: .public): \(error)")
            }
        }
    }

    nonisolated static func readSettings(at path: String) -> [String: Any] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }
}
