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
    /// 0.0–1.0 while a page is loading; mirrors `WKWebView.estimatedProgress`
    /// to drive a thin progress indicator below the address bar.
    var estimatedProgress: Double = 0
    /// Set when the most recent navigation failed (e.g. the dev server isn't
    /// running yet). Cleared as soon as a new navigation starts.
    var loadErrorMessage: String?
    /// While true the empty-URL placeholder is suppressed. Set for WebKit-initiated
    /// tabs (window.open) where the navigation has already started and the
    /// placeholder would flash briefly before `isLoading` is observed.
    private(set) var suppressPlaceholder = false

    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var didInitialLoad = false
    /// The navigation most recently started via `load(urlString:)`. Used to
    /// tell apart failures of a navigation we explicitly requested (which
    /// should surface as a full-panel error) from failures of page-initiated
    /// navigations, like a link to a blocked scheme or a broken sub-link,
    /// which shouldn't blank out a page that's still valid and visible.
    @ObservationIgnored var currentNavigation: WKNavigation?
    /// The URL most recently passed to `load(urlString:)`. Unlike `urlString`
    /// (which mirrors `WKWebView.url` and can roll back to the previous page
    /// once a failed navigation is no longer provisional), this stays put so
    /// `retry()` re-attempts the URL that actually failed.
    @ObservationIgnored private var requestedURLString = WebViewStore.defaultURLString

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

    /// Initializes the store with an existing `WKWebViewConfiguration`.
    /// Used when WebKit creates a new window (target=_blank / window.open())
    /// and provides a configuration that must be reused for the new WebView.
    init(configuration: WKWebViewConfiguration) {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        // Apply the same mobile layout preference as the default init. The
        // configuration object is provided by WebKit (window.open / target=_blank)
        // so we don't mutate it before passing it to WKWebView, but we can safely
        // update defaultWebpagePreferences on the view's own stored copy after init.
        webView.configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        webView.autoresizingMask = [.width, .height]
        self.webView = webView
        // The navigation has already started inside WebKit; suppress the placeholder
        // until the URL commits so it doesn't flash over the loading page.
        suppressPlaceholder = true
        installObservations()
    }

    deinit {
        // Explicitly invalidate KVO tokens so the observed WKWebView is released
        // promptly rather than waiting for the array to deallocate on its own.
        observations.removeAll()
    }

    /// Prevents `viewDidLayout` from loading `about:blank` when WebKit has
    /// already started a navigation into this WebView (e.g. via window.open()).
    func skipInitialLoad() {
        didInitialLoad = true
    }

    /// Records the URL for `retry()` without starting a navigation.
    /// Call this for WebKit-owned navigations (window.open) where
    /// `load(urlString:)` is never invoked directly.
    func setInitialURL(_ urlString: String) {
        requestedURLString = urlString
    }

    private func installObservations() {
        // WKWebView mutates these properties on the main thread, so the KVO
        // callbacks already arrive there. Routing them through `Task { @MainActor }`
        // would hop through the task scheduler as independent unstructured tasks,
        // letting updates (e.g. `url` vs. `isLoading`) land out of order and the
        // address bar flicker. `assumeIsolated` applies them synchronously instead.
        observations.append(webView.observe(\.isLoading, options: [.new]) { [weak self] _, change in
            guard let self else { return }
            let value = change.newValue ?? false
            MainActor.assumeIsolated { self.isLoading = value }
        })

        observations.append(webView.observe(\.title, options: [.new]) { [weak self] _, change in
            guard let self else { return }
            let value = (change.newValue ?? nil) ?? ""
            MainActor.assumeIsolated { self.title = value }
        })

        observations.append(webView.observe(\.url, options: [.new]) { [weak self] _, change in
            guard let self else { return }
            let urlString = (change.newValue ?? nil)?.absoluteString
            MainActor.assumeIsolated {
                if let urlString {
                    self.urlString = urlString
                    // Clear placeholder suppression once a real URL commits.
                    if urlString != WebViewStore.defaultURLString {
                        self.suppressPlaceholder = false
                    }
                }
            }
        })

        observations.append(webView.observe(\.canGoBack, options: [.new]) { [weak self] _, change in
            guard let self else { return }
            let value = change.newValue ?? false
            MainActor.assumeIsolated { self.canGoBack = value }
        })

        observations.append(webView.observe(\.canGoForward, options: [.new]) { [weak self] _, change in
            guard let self else { return }
            let value = change.newValue ?? false
            MainActor.assumeIsolated { self.canGoForward = value }
        })

        observations.append(webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
            guard let self else { return }
            let value = change.newValue ?? 0
            MainActor.assumeIsolated { self.estimatedProgress = value }
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
        requestedURLString = urlString
        guard let url = URL(string: urlString) else { return }
        currentNavigation = webView.load(URLRequest(url: url))
    }

    func goBack() {
        guard webView.canGoBack else { return }
        webView.goBack()
    }

    func goForward() {
        guard webView.canGoForward else { return }
        webView.goForward()
    }

    /// Re-attempts the most recently requested URL after a load failure.
    func retry() {
        load(urlString: requestedURLString)
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
        } else if loadErrorMessage != nil {
            // The last navigation never committed, so there's nothing for
            // `webView.reload()` to reload — re-issue the request instead,
            // matching the error overlay's Retry button.
            retry()
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
        estimatedProgress = 0
        loadErrorMessage = nil
        currentNavigation = nil
        suppressPlaceholder = false

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
