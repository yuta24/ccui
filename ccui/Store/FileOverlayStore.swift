import Foundation

@Observable
@MainActor
final class FileOverlayStore {
    var isVisible: Bool = false
    var selectedFile: FileNode?
    var treeFraction: CGFloat = 0.25

    static let minTreeFraction: CGFloat = 0.15
    static let maxTreeFraction: CGFloat = 0.45

    func toggle() {
        isVisible.toggle()
    }

    func open() {
        isVisible = true
    }

    func close() {
        isVisible = false
        selectedFile = nil
    }

    func selectFile(_ node: FileNode) {
        selectedFile = node
    }

    func deselectFile() {
        selectedFile = nil
    }
}
