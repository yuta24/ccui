import Foundation

/// Store 間のカスケード処理を疎結合に通知するための pub/sub バス。
/// 各 Store は `subscribe` で関心のあるイベントだけを受け取り、自分自身を更新する。
@MainActor
final class AppEventBus {
    private var handlers: [(AppEvent) -> Void] = []

    /// イベントを受信するハンドラを登録する。
    func subscribe(_ handler: @escaping (AppEvent) -> Void) {
        handlers.append(handler)
    }

    /// イベントを全ハンドラへ配信する。
    func publish(_ event: AppEvent) {
        for handler in handlers {
            handler(event)
        }
    }
}
