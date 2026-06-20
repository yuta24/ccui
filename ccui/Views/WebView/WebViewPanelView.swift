import SwiftUI
import WebKit

struct WebViewPanelView: View {
    let worktree: Worktree
    @Bindable var tabsStore: WebViewTabsStore
    @Environment(TerminalSessionStore.self) private var terminalSessionStore

    var body: some View {
        // Hoist once so all references in this body read the same object and
        // SwiftUI tracks `activeTab` / `activeTabIndex` only at this level.
        let activeStore = tabsStore.activeTab.store

        VStack(spacing: 0) {
            if tabsStore.tabs.count > 1 {
                WebViewTabBar(tabsStore: tabsStore)
            }

            AddressBarView(
                worktree: worktree,
                store: activeStore,
                onAddTab: { tabsStore.addTab() }
            )
            // Force recreation when switching tabs so @State (inputText, isFocused)
            // resets to the new tab's URL via onAppear.
            .id(ObjectIdentifier(activeStore))

            // WebViewLoadingBar reads isLoading and estimatedProgress from the store.
            // Scoping them to a child view limits @Observable re-renders to just the
            // progress bar instead of the entire WebViewPanelView body (~60 Hz during load).
            WebViewLoadingBar(store: activeStore)

            ZStack {
                // All tab WebViews are kept alive in the hierarchy. Only the
                // active tab is visible and interactive; hidden tabs continue to
                // run (JS, loading) so their state is preserved when switching.
                ForEach(tabsStore.tabs) { tab in
                    let isActive = tab.id == tabsStore.activeTab.id
                    WebViewRepresentable(
                        store: tab.store,
                        onCreateNewTab: { configuration, urlString in
                            let newTab = tabsStore.addTab(configuration: configuration, initialURL: urlString)
                            return newTab.store.webView
                        }
                    )
                    .opacity(isActive ? 1 : 0)
                    .allowsHitTesting(isActive)
                    .accessibilityHidden(!isActive)
                }

                if let message = activeStore.loadErrorMessage {
                    WebViewErrorView(message: message) {
                        activeStore.retry()
                    }
                } else if activeStore.urlString == WebViewStore.defaultURLString,
                          !activeStore.isLoading,
                          !activeStore.suppressPlaceholder {
                    WebViewPlaceholderView()
                }

                if activeStore.loadErrorMessage == nil,
                   activeStore.isRegionCaptureActive,
                   let session = terminalSessionStore.session(for: worktree)
                {
                    RegionCaptureOverlayView(
                        worktree: worktree,
                        store: activeStore,
                        session: session
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.surfacePrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tab Bar

private struct WebViewTabBar: View {
    @Bindable var tabsStore: WebViewTabsStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Use tab.id (UUID) in closures rather than a captured enumerated index,
                // so selection and close remain correct even if tabs mutate before the
                // user's tap is processed.
                ForEach(tabsStore.tabs) { tab in
                    WebViewTabBarItem(
                        tab: tab,
                        isActive: tab.id == tabsStore.activeTab.id,
                        onSelect: { tabsStore.selectTab(id: tab.id) },
                        onClose: { tabsStore.closeTab(id: tab.id) }
                    )
                }
            }
        }
        .frame(height: 28)
        .background(Color.surfacePrimary)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderSubtle).frame(height: 1)
        }
    }
}

private struct WebViewTabBarItem: View {
    let tab: WebViewTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        // Use a Button for selection so its gesture takes the correct priority.
        // The close button is placed in an overlay so it sits above the selection
        // button in hit-test order, avoiding the .onTapGesture vs Button conflict
        // that causes the × to trigger selection instead of close on macOS.
        Button(action: onSelect) {
            HStack(spacing: 4) {
                Text(tab.store.title.isEmpty ? "New Tab" : tab.store.title)
                    .font(.uiCaption)
                    .foregroundStyle(isActive ? Color.textPrimary : Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 120, alignment: .leading)
                Color.clear.frame(width: 16) // reserve space for the close button
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(isActive ? Color.surfaceHover : Color.clear)
        .overlay(alignment: .trailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.iconClose)
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle().fill(Color.accent).frame(height: 2)
            }
        }
    }
}

// MARK: - Loading Bar

/// Thin progress indicator scoped to its own View so that `estimatedProgress`
/// KVO updates (~60 Hz during a page load) only invalidate this subtree instead
/// of the entire `WebViewPanelView` body.
private struct WebViewLoadingBar: View {
    let store: WebViewStore

    var body: some View {
        if store.isLoading {
            WebViewProgressBar(progress: store.estimatedProgress)
        }
    }
}

// MARK: - Progress Bar

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
