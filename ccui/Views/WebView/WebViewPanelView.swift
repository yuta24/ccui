import SwiftUI
import WebKit

struct WebViewPanelView: View {
    let worktree: Worktree
    @Bindable var tabsStore: WebViewTabsStore
    @Environment(TerminalSessionStore.self) private var terminalSessionStore

    var body: some View {
        VStack(spacing: 0) {
            if tabsStore.tabs.count > 1 {
                WebViewTabBar(tabsStore: tabsStore)
            }

            AddressBarView(
                worktree: worktree,
                store: tabsStore.activeTab.store,
                onAddTab: { tabsStore.addTab() }
            )
            // Force recreation when switching tabs so @State (inputText, isFocused)
            // resets to the new tab's URL via onAppear.
            .id(ObjectIdentifier(tabsStore.activeTab.store))

            if tabsStore.activeTab.store.isLoading {
                WebViewProgressBar(progress: tabsStore.activeTab.store.estimatedProgress)
            }

            ZStack {
                // All tab WebViews are kept alive in the hierarchy. Only the
                // active tab is visible and interactive; hidden tabs continue to
                // run (JS, loading) so their state is preserved when switching.
                ForEach(tabsStore.tabs) { tab in
                    let isActive = tab.id == tabsStore.activeTab.id
                    WebViewRepresentable(
                        store: tab.store,
                        onCreateNewTab: { configuration in
                            let newTab = tabsStore.addTab(configuration: configuration)
                            return newTab.store.webView
                        }
                    )
                    .opacity(isActive ? 1 : 0)
                    .allowsHitTesting(isActive)
                    .accessibilityHidden(!isActive)
                }

                let activeStore = tabsStore.activeTab.store
                if let message = activeStore.loadErrorMessage {
                    WebViewErrorView(message: message) {
                        activeStore.retry()
                    }
                } else if activeStore.urlString == WebViewStore.defaultURLString, !activeStore.isLoading {
                    WebViewPlaceholderView()
                }

                if tabsStore.activeTab.store.loadErrorMessage == nil,
                   tabsStore.activeTab.store.isRegionCaptureActive,
                   let session = terminalSessionStore.session(for: worktree)
                {
                    RegionCaptureOverlayView(
                        worktree: worktree,
                        store: tabsStore.activeTab.store,
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
                ForEach(Array(tabsStore.tabs.enumerated()), id: \.element.id) { index, tab in
                    WebViewTabBarItem(
                        tab: tab,
                        isActive: tab.id == tabsStore.activeTab.id,
                        onSelect: { tabsStore.selectTab(at: index) },
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
                    .font(.system(size: 8, weight: .medium))
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
