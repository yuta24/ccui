import Foundation
import CoreServices

@MainActor
final class FileWatcherService {
    nonisolated(unsafe) private var stream: FSEventStreamRef?
    nonisolated(unsafe) private var debounceTask: Task<Void, Never>?
    nonisolated(unsafe) private var onChange: (@MainActor () -> Void)?
    nonisolated(unsafe) private var retainedSelf: Unmanaged<FileWatcherService>?

    func start(path: String, onChange: @escaping @MainActor () -> Void) {
        stop()
        self.onChange = onChange

        let retained = Unmanaged.passRetained(self)
        retainedSelf = retained

        var context = FSEventStreamContext(
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
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            FSEventStreamCreateFlags(flags)
        ) else {
            retained.release()
            retainedSelf = nil
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil

        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }

        if let retainedSelf {
            retainedSelf.release()
            self.retainedSelf = nil
        }

        onChange = nil
    }

    fileprivate func handleEvent() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.onChange?()
        }
    }

    deinit {
        // Safety net: callers should call stop() explicitly before releasing.
        // Direct cleanup here since deinit is nonisolated.
        debounceTask?.cancel()
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        retainedSelf?.release()
    }
}

private nonisolated let fsEventCallback: FSEventStreamCallback = {
    _, clientCallBackInfo, _, _, _, _ in
    guard let info = clientCallBackInfo else { return }
    let service = Unmanaged<FileWatcherService>.fromOpaque(info).takeUnretainedValue()
    MainActor.assumeIsolated {
        service.handleEvent()
    }
}
