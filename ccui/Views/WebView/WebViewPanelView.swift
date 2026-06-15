import SwiftUI

struct WebViewPanelView: View {
    let worktree: Worktree
    @Bindable var store: WebViewStore
    @Environment(TerminalSessionStore.self) private var terminalSessionStore

    var body: some View {
        VStack(spacing: 0) {
            AddressBarView(worktree: worktree, store: store)

            if store.isLoading {
                WebViewProgressBar(progress: store.estimatedProgress)
            }

            ZStack {
                WebViewRepresentable(store: store)

                if let message = store.loadErrorMessage {
                    WebViewErrorView(message: message) {
                        store.retry()
                    }
                } else if store.urlString == WebViewStore.defaultURLString, !store.isLoading {
                    WebViewPlaceholderView()
                }

                if store.loadErrorMessage == nil, store.isRegionCaptureActive,
                   let session = terminalSessionStore.session(for: worktree) {
                    RegionCaptureOverlayView(worktree: worktree, store: store, session: session)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.surfacePrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Thin loading-progress indicator shown below the address bar while a page
/// is loading, mirroring `WKWebView.estimatedProgress`.
private struct WebViewProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(Color.accent)
                .frame(width: proxy.size.width * max(0, min(1, progress)))
                .animation(.easeOut(duration: 0.2), value: progress)
        }
        .frame(height: 2)
    }
}
