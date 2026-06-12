import SwiftUI

struct MainContentView: View {
    let stores: AppDependencies

    var body: some View {
        NavigationSplitView {
            SidebarContainerView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
        } detail: {
            DetailPaneRepresentable(stores: stores)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar(removing: .sidebarToggle)
    }
}
