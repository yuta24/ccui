import Foundation

/// `~/Library/Logs/DiagnosticReports/` から、このアプリの直近のクラッシュレポートを探す。
enum CrashReportFinder {
    static func latestReport(
        processName: String = "ccui",
        directory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Logs/DiagnosticReports"),
        within interval: TimeInterval = 7 * 24 * 60 * 60,
        now: Date = Date()
    ) -> URL? {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return nil
        }

        let cutoff = now.addingTimeInterval(-interval)
        let prefixes = ["\(processName)-", "\(processName)_"]

        return entries
            .filter { url in
                ["ips", "crash"].contains(url.pathExtension)
                    && prefixes.contains { url.lastPathComponent.hasPrefix($0) }
            }
            .compactMap { url -> (URL, Date)? in
                guard let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                    return nil
                }
                return (url, date)
            }
            .filter { $0.1 >= cutoff }
            .max { $0.1 < $1.1 }?
            .0
    }
}
