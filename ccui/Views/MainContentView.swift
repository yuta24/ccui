import SwiftUI

struct MainContentView: View {
    let stores: StoreContainer

    var body: some View {
        NavigationSplitView {
            SidebarContainerView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
        } detail: {
            DetailPaneRepresentable(stores: stores)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        }
        .toolbar(removing: .sidebarToggle)
        .ignoresSafeArea()
    }
}
