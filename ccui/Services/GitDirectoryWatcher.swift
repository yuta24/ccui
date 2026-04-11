import Foundation

@MainActor
final class GitDirectoryWatcher {
    private var state: WatcherState?

    func start(repositoryPath: String, onChange: @escaping @Sendable () -> Void) {
        stop()

        let gitDir = (repositoryPath as NSString).appendingPathComponent(".git")
        var watchDirs = [gitDir]

        let worktreesDir = (gitDir as NSString).appendingPathComponent("worktrees")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: worktreesDir, isDirectory: &isDir), isDir.boolValue {
            watchDirs.append(worktreesDir)

            if let entries = try? FileManager.default.contentsOfDirectory(atPath: worktreesDir) {
                for entry in entries {
                    let dir = (worktreesDir as NSString).appendingPathComponent(entry)
                    var entryIsDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: dir, isDirectory: &entryIsDir), entryIsDir.boolValue {
                        watchDirs.append(dir)
                    }
                }
            }
        }

        let newState = WatcherState()
        for dir in watchDirs {
            let fd = open(dir, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: .write,
                queue: .global(qos: .utility)
            )
            source.setEventHandler {
                onChange()
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            newState.sources.append(source)
        }
        state = newState
    }

    func stop() {
        state?.cancelAll()
        state = nil
    }

    deinit {
        state?.cancelAll()
    }
}

// MARK: - Watcher State

/// Holds dispatch sources in a sendable container so `deinit` can safely
/// cancel them from outside the MainActor.
/// `DispatchSource.cancel()` is thread-safe, so calling it from `deinit` is safe.
private final class WatcherState: @unchecked Sendable {
    var sources: [DispatchSourceFileSystemObject] = []

    func cancelAll() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
    }
}
