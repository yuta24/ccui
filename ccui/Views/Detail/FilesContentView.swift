import SwiftUI

struct FilesContentView: View {
    let fileTreeStore: FileTreeStore?
    let fileOverlayStore: FileOverlayStore
    let codeViewerStore: CodeViewerStore
    let searchStore: SearchStore
    let repositoryPath: String

    var body: some View {
        FileExplorerContent(
            store: fileOverlayStore,
            fileTreeStore: fileTreeStore,
            codeViewerStore: codeViewerStore,
            searchStore: searchStore,
            repositoryPath: repositoryPath
        )
    }
}
