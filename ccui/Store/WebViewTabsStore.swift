import WebKit

@Observable
@MainActor
final class WebViewTabsStore {
    private(set) var tabs: [WebViewTab] = []
    // Private setter prevents callers from writing an out-of-range index directly.
    // Use selectTab(at:) / selectTab(id:) to change the active tab.
    private(set) var activeTabIndex: Int = 0

    var activeTab: WebViewTab { tabs[activeTabIndex] }

    init() {
        tabs = [WebViewTab()]
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        // Deactivate region capture on the tab being left so it doesn't
        // reappear unexpectedly when the user switches back.
        tabs[activeTabIndex].store.isRegionCaptureActive = false
        activeTabIndex = index
    }

    /// Selects the tab with the given ID. Prefer this over `selectTab(at:)` in
    /// closures that capture a tab identity, since UUID references are stable
    /// across concurrent mutations whereas a captured integer index can go stale.
    func selectTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        selectTab(at: index)
    }

    @discardableResult
    func addTab(configuration: WKWebViewConfiguration? = nil, initialURL: String? = nil) -> WebViewTab {
        let tab: WebViewTab
        if let configuration {
            tab = WebViewTab(configuration: configuration)
            // WebKit has already started a navigation into the returned WKWebView;
            // prevent viewDidLayout from loading about:blank over it.
            tab.store.skipInitialLoad()
            // Record the target URL so retry() can re-attempt it if the load fails.
            if let url = initialURL {
                tab.store.setInitialURL(url)
            }
        } else {
            tab = WebViewTab()
        }
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        return tab
    }

    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return }
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        if activeTabIndex > index {
            activeTabIndex -= 1
        } else if activeTabIndex >= tabs.count {
            activeTabIndex = tabs.count - 1
        }
    }

    func reset() {
        tabs = [WebViewTab()]
        activeTabIndex = 0
        // No need to call tabs[0].store.reset() — the freshly created WebViewStore
        // already starts in the default state and has a zero-size frame, so
        // viewDidLayout will handle the initial load once the panel is visible.
    }
}
