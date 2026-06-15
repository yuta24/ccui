import Foundation
import Testing
@testable import ccui

/// `CrashReportFinder` のファイル名 (prefix/extension) と日時フィルタの挙動を検証する。
struct CrashReportFinderTests {

    // MARK: - Helpers

    private static func makeTempDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "ccui-crash-report-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func writeFile(_ name: String, in dir: URL, modified: Date) throws {
        let url = dir.appending(path: name)
        try "report".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
    }

    // MARK: - Tests

    @Test func returnsNilWhenDirectoryIsEmpty() throws {
        let dir = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(CrashReportFinder.latestReport(directory: dir) == nil)
    }

    @Test func returnsNilWhenDirectoryDoesNotExist() {
        let dir = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)")

        #expect(CrashReportFinder.latestReport(directory: dir) == nil)
    }

    @Test func picksMostRecentMatchingReport() throws {
        let dir = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let now = Date()
        try Self.writeFile("ccui-2026-06-10-100000.ips", in: dir, modified: now.addingTimeInterval(-3600))
        try Self.writeFile("ccui-2026-06-15-100000.ips", in: dir, modified: now)
        try Self.writeFile("ccui_2026-06-09_host.crash", in: dir, modified: now.addingTimeInterval(-7200))

        let result = CrashReportFinder.latestReport(directory: dir, now: now)
        #expect(result?.lastPathComponent == "ccui-2026-06-15-100000.ips")
    }

    @Test func ignoresUnrelatedProcessesAndExtensions() throws {
        let dir = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let now = Date()
        try Self.writeFile("ccuiTests-2026-06-15-100000.ips", in: dir, modified: now)
        try Self.writeFile("other-2026-06-15-100000.ips", in: dir, modified: now)
        try Self.writeFile("ccui-2026-06-15-100000.txt", in: dir, modified: now)

        #expect(CrashReportFinder.latestReport(directory: dir, now: now) == nil)
    }

    @Test func ignoresReportsOlderThanInterval() throws {
        let dir = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let now = Date()
        try Self.writeFile("ccui-2026-05-01-100000.ips", in: dir, modified: now.addingTimeInterval(-30 * 24 * 60 * 60))

        let result = CrashReportFinder.latestReport(directory: dir, within: 7 * 24 * 60 * 60, now: now)
        #expect(result == nil)
    }
}
