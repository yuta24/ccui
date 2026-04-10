import Foundation

@MainActor
final class GitDirectoryWatcher {
    // Accessed from deinit (off MainActor). Only deinit reads this without
    // actor isolation; start/stop always run on MainActor.
    // DispatchSource.cancel() is thread-safe, so the deinit cancel loop is safe.
    nonisolated(unsafe) private var sources: [DispatchSourceFileSystemObject] = []

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
            sources.append(source)
        }
    }

    func stop() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
    }

    deinit {
        for source in sources {
            source.cancel()
        }
    }
}
