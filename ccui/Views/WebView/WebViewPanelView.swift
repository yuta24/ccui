import SwiftUI

struct WebViewPanelView: View {
    let worktree: Worktree
    @Bindable var store: WebViewStore
    @Environment(TerminalSessionStore.self) private var terminalSessionStore

    var body: some View {
        VStack(spacing: 0) {
            AddressBarView(worktree: worktree, store: store)
            ZStack {
                WebViewRepresentable(store: store)

                if store.isRegionCaptureActive,
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
