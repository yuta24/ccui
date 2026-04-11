import Foundation
import CoreServices
import os

@MainActor
final class FileWatcherService {
    private var context: StreamContext?

    func start(path: String, onChange: @escaping @MainActor () -> Void) {
        stop()

        let ctx = StreamContext(onChange: onChange)
        let retained = Unmanaged.passRetained(ctx)

        var fsContext = FSEventStreamContext(
            version: 0,
            info: retained.toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let paths = [path as CFString] as CFArray
        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &fsContext,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            FSEventStreamCreateFlags(flags)
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
        context?.invalidate()
    }
}

// MARK: - Stream Context

/// Separate `@unchecked Sendable` context passed to the C callback.
/// Avoids retaining `FileWatcherService` itself via `Unmanaged`, eliminating
/// the self-retain cycle that previously required manual `release()` calls.
private final class StreamContext: @unchecked Sendable {
    let onChange: @MainActor () -> Void
    var stream: FSEventStreamRef?
    var debounceTask: Task<Void, Never>?
    private let released = OSAllocatedUnfairLock(initialState: false)

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    func handleEvent() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.onChange()
        }
    }

    func invalidate() {
        debounceTask?.cancel()
        debounceTask = nil

        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }

        let alreadyReleased = released.withLock { value in
            let was = value
            value = true
            return was
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
    MainActor.assumeIsolated {
        ctx.handleEvent()
    }
}
