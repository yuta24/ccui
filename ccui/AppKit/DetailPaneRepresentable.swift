import SwiftUI

struct DetailPaneRepresentable: NSViewControllerRepresentable {
    let stores: StoreContainer

    func makeNSViewController(context: Context) -> DetailPaneViewController {
        DetailPaneViewController(stores: stores)
    }

    func updateNSViewController(_ nsViewController: DetailPaneViewController, context: Context) {}
}
