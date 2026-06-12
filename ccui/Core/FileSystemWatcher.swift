import CoreServices
import Foundation
import os

/// FSEventStream をラップした汎用ファイルシステム監視。
/// 単一/複数パスの監視、ファイル単位イベントの有無、デバウンスの有無を
/// パラメータ化することで、ファイル変更監視・`.git` 配下のディレクトリ変更監視の
/// 双方をカバーする。
@MainActor
final class FileSystemWatcher {
    private var context: StreamContext?

    /// - Parameters:
    ///   - paths: 監視対象パス一覧。
    ///   - latency: FSEventStream のイベント遅延（秒）。
    ///   - fileEvents: `true` の場合ファイル単位の変更を通知する（`kFSEventStreamCreateFlagFileEvents`）。
    ///     `false` の場合は変更があったディレクトリ単位での通知になる。
    ///   - debounce: 連続するイベントをまとめる間隔。`nil` の場合は即時通知する。
    ///   - onChange: 変更検知時に呼ばれるハンドラ。
    func start(
        paths: [String],
        latency: TimeInterval = 1.0,
        fileEvents: Bool = true,
        debounce: Duration? = .seconds(2),
        onChange: @escaping @MainActor () -> Void
    ) {
        stop()
        guard !paths.isEmpty else { return }

        let ctx = StreamContext(onChange: onChange, debounce: debounce)
        let retained = Unmanaged.passRetained(ctx)

        var fsContext = FSEventStreamContext(
            version: 0,
            info: retained.toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let cfPaths = paths.map { $0 as CFString } as CFArray

        var rawFlags = kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer
        if fileEvents {
            rawFlags |= kFSEventStreamCreateFlagFileEvents
        }

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &fsContext,
            cfPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            FSEventStreamCreateFlags(rawFlags)
        ) else {
            retained.release()
            return
        }

        ctx.stream = stream
        self.context = ctx

        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    func stop() {
        context?.invalidate()
        context = nil
    }

    deinit {
        // @MainActor クラスでも Swift 6 の deinit は非 isolated。
        // FSEventStream API はメインキューで scheduling されているため、
        // 別スレッドから Stop/Invalidate/Release を呼ぶと crash しうる。
        // 通常は stop() で context が nil 化されているが、保険として
        // 残っていた場合は MainActor に hop してから invalidate を実行する。
        if let ctx = context {
            Task { @MainActor in
                ctx.invalidate()
            }
        }
    }
}

// MARK: - Stream Context

/// C コールバックへ渡す `@unchecked Sendable` context。
/// `Unmanaged` を用いることで `FileSystemWatcher` 自身を retain させず、
/// 自己参照サイクルと手動 release の必要性を排除する。
private final class StreamContext: @unchecked Sendable {
    let onChange: @MainActor () -> Void
    let debounce: Duration?
    var stream: FSEventStreamRef?
    var debounceTask: Task<Void, Never>?
    private let released = OSAllocatedUnfairLock(initialState: false)

    init(onChange: @escaping @MainActor () -> Void, debounce: Duration?) {
        self.onChange = onChange
        self.debounce = debounce
    }

    func handleEvent() {
        let isReleased = released.withLock { $0 }
        guard !isReleased else { return }

        guard let debounce else {
            Task { @MainActor [onChange] in
                onChange()
            }
            return
        }

        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            self?.onChange()
        }
    }

    func invalidate() {
        let alreadyReleased = released.withLock { value in
            let was = value
            value = true
            return was
        }

        debounceTask?.cancel()
        debounceTask = nil

        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }

        guard !alreadyReleased else { return }
        Unmanaged.passUnretained(self).release()
    }
}

// MARK: - C Callback

private nonisolated let fsEventCallback: FSEventStreamCallback = {
    _, clientCallBackInfo, _, _, _, _ in
    guard let info = clientCallBackInfo else { return }
    let ctx = Unmanaged<StreamContext>.fromOpaque(info).takeUnretainedValue()
    Task { @MainActor in
        ctx.handleEvent()
    }
}
