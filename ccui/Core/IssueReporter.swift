import AppKit

/// 「問題を報告」メニューから、クラッシュレポートの場所を案内しつつ GitHub Issue 作成画面を開く。
enum IssueReporter {
    static let newIssueURL = URL(string: "https://github.com/yuta24/ccui/issues/new")!

    @MainActor
    static func report() {
        if let crashReport = CrashReportFinder.latestReport() {
            NSWorkspace.shared.activateFileViewerSelecting([crashReport])
        }

        guard let url = issueURL() else { return }
        NSWorkspace.shared.open(url)
    }

    static func issueURL(
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString
    ) -> URL? {
        var components = URLComponents(url: newIssueURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "body", value: issueBody(appVersion: appVersion, osVersion: osVersion))]
        return components?.url
    }

    private static func issueBody(appVersion: String, osVersion: String) -> String {
        """
        <!-- 発生した問題の内容を記載してください -->


        ## 環境
        - ccui: \(appVersion)
        - macOS: \(osVersion)

        ## クラッシュログ
        <!-- アプリがクラッシュした場合、Finder に表示されたログファイル (.ips) をこの Issue にドラッグ&ドロップして添付してください -->
        """
    }
}
