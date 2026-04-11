import SwiftUI

struct FileOverlayView: View {
    let store: FileOverlayStore
    let fileTreeStore: FileTreeStore?
    let diffStore: DiffStore
    let codeViewerStore: CodeViewerStore
    let repositoryPath: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    store.close()
                }

            GeometryReader { geometry in
                let panelWidth = geometry.size.width * 0.85
                let panelHeight = geometry.size.height * 0.85

                FileExplorerContent(
                    store: store,
                    fileTreeStore: fileTreeStore,
                    diffStore: diffStore,
                    codeViewerStore: codeViewerStore,
                    repositoryPath: repositoryPath
                )
                .frame(width: panelWidth, height: panelHeight)
                .background(Color.surfaceBase)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.borderDefault, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 8)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }
}
