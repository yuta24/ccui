import Foundation
import Testing
@testable import ccui

/// `IssueReporter.issueURL` が GitHub Issue 作成画面への正しい URL を組み立てることを検証する。
struct IssueReporterTests {

    @Test func buildsIssueURLWithEnvironmentInfo() throws {
        let url = try #require(IssueReporter.issueURL(appVersion: "1.2.3", osVersion: "macOS 15.0"))

        #expect(url.absoluteString.hasPrefix("https://github.com/yuta24/ccui/issues/new?body="))

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let body = try #require(components.queryItems?.first { $0.name == "body" }?.value)
        #expect(body.contains("ccui: 1.2.3"))
        #expect(body.contains("macOS: macOS 15.0"))
    }
}
