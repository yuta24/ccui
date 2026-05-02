import Foundation
import Observation
import WebKit

@Observable
@MainActor
final class WebViewStore {
    static let defaultURLString = "about:blank"

    @ObservationIgnored let webView: WKWebView

    var urlString: String = WebViewStore.defaultURLString
    var isLoading = false
    var canGoBack = false
    var canGoForward = false
    var title: String = ""

    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var didInitialLoad = false

    init() {
        let config = WKWebViewConfiguration()
        // Request mobile layout so sites reflow to fit the side-panel width
        // instead of forcing a desktop-width viewport that overflows.
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.autoresizingMask = [.width, .height]
        self.webView = webView
        installObservations()
    }

    private func installObservations() {
        observations.append(webView.observe(\.isLoading, options: [.new]) { _, change in
            let value = change.newValue ?? false
            Task { @MainActor [weak self] in self?.isLoading = value }
        })

        observations.append(webView.observe(\.title, options: [.new]) { _, change in
            let value = (change.newValue ?? nil) ?? ""
            Task { @MainActor [weak self] in self?.title = value }
        })

        observations.append(webView.observe(\.url, options: [.new]) { _, change in
            let urlString = (change.newValue ?? nil)?.absoluteString
            Task { @MainActor [weak self] in
                if let urlString { self?.urlString = urlString }
            }
        })

        observations.append(webView.observe(\.canGoBack, options: [.new]) { _, change in
            let value = change.newValue ?? false
            Task { @MainActor [weak self] in self?.canGoBack = value }
        })

        observations.append(webView.observe(\.canGoForward, options: [.new]) { _, change in
            let value = change.newValue ?? false
            Task { @MainActor [weak self] in self?.canGoForward = value }
        })
    }

    /// Marks initial load as performed. Returns true if this was the first call.
    func consumeInitialLoadFlag() -> Bool {
        guard !didInitialLoad else { return false }
        didInitialLoad = true
        return true
    }

    func load(urlString: String) {
        self.urlString = urlString
        guard let url = URL(string: urlString) else { return }
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        guard webView.canGoBack else { return }
        webView.goBack()
    }

    func goForward() {
        guard webView.canGoForward else { return }
        webView.goForward()
    }

    func reload() {
        if isLoading {
            webView.stopLoading()
        } else {
            webView.reload()
        }
    }

    /// Resets the WebView state when switching worktrees.
    func reset() {
        if let url = URL(string: WebViewStore.defaultURLString) {
            webView.load(URLRequest(url: url))
        }
        urlString = WebViewStore.defaultURLString
        title = ""
        isLoading = false
        canGoBack = false
        canGoForward = false
        didInitialLoad = false
    }
}
