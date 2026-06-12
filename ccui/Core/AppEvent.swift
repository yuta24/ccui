import Foundation

/// Store 間のカスケード処理を `AppEventBus` 経由で通知するためのイベント。
enum AppEvent: Sendable {
    /// repositories の変更に伴い worktree 一覧が同期された。
    /// `allWorktreePaths` は同期後に存在する全 worktree のパス集合。
    case worktreesSynced(allWorktreePaths: Set<String>)

    /// repository が削除され、配下の worktree が失われた。
    case repositoriesRemoved(worktreePaths: Set<String>)

    /// repository の worktree 一覧読み込みが完了した。
    case worktreesLoaded(repositoryPath: String, paths: Set<String>)

    /// 単一の worktree が削除された。
    case worktreeRemoved(path: String)
}
