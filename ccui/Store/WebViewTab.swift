import WebKit

@Observable
@MainActor
final class WebViewTab: Identifiable {
    let id: UUID
    let store: WebViewStore

    init() {
        self.id = UUID()
        self.store = WebViewStore()
    }

    init(configuration: WKWebViewConfiguration) {
        self.id = UUID()
        self.store = WebViewStore(configuration: configuration)
    }
}
