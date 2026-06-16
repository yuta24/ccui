import WebKit

@Observable
@MainActor
final class WebViewTabsStore {
    private(set) var tabs: [WebViewTab] = []
    // Private setter prevents callers from writing an out-of-range index directly.
    // Use selectTab(at:) to change the active tab.
    private(set) var activeTabIndex: Int = 0

    var activeTab: WebViewTab { tabs[activeTabIndex] }

    init() {
        tabs = [WebViewTab()]
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        activeTabIndex = index
    }

    @discardableResult
    func addTab(configuration: WKWebViewConfiguration? = nil) -> WebViewTab {
        let tab: WebViewTab
        if let configuration {
            tab = WebViewTab(configuration: configuration)
            // WebKit has already started a navigation into the returned WKWebView;
            // prevent viewDidLayout from loading about:blank over it.
            tab.store.skipInitialLoad()
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
        tabs[0].store.reset()
    }
}
