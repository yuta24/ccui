import AppKit
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
    /// When true, the panel shows a drag-to-select overlay for capturing a
    /// region of the page as an image to send to the agent.
    var isRegionCaptureActive = false

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
        // WKWebView mutates these properties on the main thread, so the KVO
        // callbacks already arrive there. Routing them through `Task { @MainActor }`
        // would hop through the task scheduler as independent unstructured tasks,
        // letting updates (e.g. `url` vs. `isLoading`) land out of order and the
        // address bar flicker. `assumeIsolated` applies them synchronously instead.
        observations.append(webView.observe(\.isLoading, options: [.new]) { [weak self] _, change in
            let value = change.newValue ?? false
            MainActor.assumeIsolated { self?.isLoading = value }
        })

        observations.append(webView.observe(\.title, options: [.new]) { [weak self] _, change in
            let value = (change.newValue ?? nil) ?? ""
            MainActor.assumeIsolated { self?.title = value }
        })

        observations.append(webView.observe(\.url, options: [.new]) { [weak self] _, change in
            let urlString = (change.newValue ?? nil)?.absoluteString
            MainActor.assumeIsolated {
                if let urlString { self?.urlString = urlString }
            }
        })

        observations.append(webView.observe(\.canGoBack, options: [.new]) { [weak self] _, change in
            let value = change.newValue ?? false
            MainActor.assumeIsolated { self?.canGoBack = value }
        })

        observations.append(webView.observe(\.canGoForward, options: [.new]) { [weak self] _, change in
            let value = change.newValue ?? false
            MainActor.assumeIsolated { self?.canGoForward = value }
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

    /// Renders the currently visible page content to an image.
    func captureSnapshot() async -> NSImage? {
        await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: nil) { image, _ in
                continuation.resume(returning: image)
            }
        }
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
        urlString = WebViewStore.defaultURLString
        title = ""
        isLoading = false
        canGoBack = false
        canGoForward = false
        isRegionCaptureActive = false

        // A zero-size WKWebView hasn't established its render-process IPC yet
        // (see WebViewController.viewDidLayout); loading into it here would be
        // the same unsafe path that comment guards against and can leave the
        // panel blank. Only reload immediately while the panel is on-screen
        // with a real frame — otherwise let the layout-driven path in
        // WebViewController perform the load once it becomes visible again.
        guard webView.bounds.width > 0, webView.bounds.height > 0 else {
            didInitialLoad = false
            return
        }
        load(urlString: WebViewStore.defaultURLString)
        didInitialLoad = true
    }
}
