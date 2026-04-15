import Foundation

@Observable
@MainActor
final class FileOverlayStore {
    var selectedFile: FileNode?
    var treeFraction: CGFloat = 0.25

    static let minTreeFraction: CGFloat = 0.15
    static let maxTreeFraction: CGFloat = 0.45

    func selectFile(_ node: FileNode) {
        selectedFile = node
    }

    func deselectFile() {
        selectedFile = nil
    }
}
