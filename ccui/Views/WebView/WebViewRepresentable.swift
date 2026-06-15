import SwiftUI
import WebKit

/// Hosts the long-lived `WKWebView` owned by `WebViewStore`. The store is the
/// source of truth for navigation state — this representable only attaches the
/// view, performs the initial load when a non-zero frame is available, and
/// installs the navigation delegate.
struct WebViewRepresentable: NSViewControllerRepresentable {
    let store: WebViewStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeNSViewController(context: Context) -> WebViewController {
        WebViewController(store: store, navigationDelegate: context.coordinator)
    }

    func updateNSViewController(_ controller: WebViewController, context: Context) {
        // No-op. State changes flow directly through the store-owned WKWebView.
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        let store: WebViewStore

        init(store: WebViewStore) {
            self.store = store
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let scheme = navigationAction.request.url?.scheme?.lowercased() else {
                return .cancel
            }
            // Only allow safe web schemes. Block file://, javascript:, data:, etc.
            switch scheme {
            case "http", "https", "about":
                return .allow
            default:
                return .cancel
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            store.loadErrorMessage = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            // Only a navigation we explicitly requested via `load(urlString:)`
            // should be able to blank the panel with a full-screen error. A
            // page-initiated navigation (e.g. a link to a blocked scheme like
            // mailto:/tel:, or a broken sub-link) failing shouldn't cover up a
            // page that's still valid and on screen.
            guard navigation === store.currentNavigation else { return }
            showError(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard navigation === store.currentNavigation else { return }
            showError(error)
        }

        private func showError(_ error: Error) {
            let nsError = error as NSError
            guard !isCancellation(nsError) else { return }
            store.loadErrorMessage = nsError.localizedDescription
        }

        /// -999 (cancelled) fires for user-initiated stops and for navigations
        /// superseded by a newer one. `WebKitErrorDomain`/`WKErrorDomain` code
        /// 102 ("Frame load interrupted by policy change") fires when
        /// `decidePolicyFor` returns `.cancel`, e.g. a redirect into a blocked
        /// scheme. Neither is a real failure.
        private func isCancellation(_ error: NSError) -> Bool {
            if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                return true
            }
            if (error.domain == "WKErrorDomain" || error.domain == "WebKitErrorDomain") && error.code == 102 {
                return true
            }
            return false
        }
    }
}

@MainActor
final class WebViewController: NSViewController {
    private let store: WebViewStore

    init(store: WebViewStore, navigationDelegate: WKNavigationDelegate) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        store.webView.navigationDelegate = navigationDelegate
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView()
        let webView = store.webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.removeFromSuperview()
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        view = container
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        // WKWebView needs a non-zero frame before its first load to establish
        // its render-process IPC. Defer the first navigation until layout.
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        if store.consumeInitialLoadFlag() {
            store.load(urlString: store.urlString)
        }
    }
}
