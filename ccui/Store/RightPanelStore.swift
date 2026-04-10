import Foundation

@Observable
@MainActor
final class RightPanelStore {
    enum PanelContent: Equatable {
        case fileTree
        case viewer(FileNode)
    }

    var isExpanded: Bool = false
    var panelWidth: CGFloat = 300
    var content: PanelContent = .fileTree

    static let minWidth: CGFloat = 200
    static let maxWidthFraction: CGFloat = 0.5

    func toggle() {
        isExpanded.toggle()
    }

    func expand() {
        isExpanded = true
    }

    func collapse() {
        isExpanded = false
    }

    func selectFile(_ node: FileNode) {
        content = .viewer(node)
    }

    func backToFileTree() {
        content = .fileTree
    }
}
