import SwiftUI

struct WebViewPanelView: View {
    @Bindable var store: WebViewStore

    var body: some View {
        VStack(spacing: 0) {
            AddressBarView(store: store)
            WebViewRepresentable(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.surfacePrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
