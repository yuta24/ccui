import SwiftUI

enum FileTreeHelpers {
    static func statusLetter(_ status: DiffFileEntry.Status) -> String {
        switch status {
        case .added: "A"
        case .modified: "M"
        case .deleted: "D"
        case .renamed: "R"
        case .untracked: "U"
        }
    }

    static func statusColor(_ status: DiffFileEntry.Status) -> Color {
        switch status {
        case .added: .diffAddition
        case .modified: .accent
        case .deleted: .diffDeletion
        case .renamed: .statusRenamed
        case .untracked: .diffAddition
        }
    }

    static func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "jsx", "ts", "tsx": return "chevron.left.forwardslash.chevron.right"
        case "json": return "curlybraces"
        case "md", "txt": return "doc.plaintext"
        case "yml", "yaml", "toml": return "gearshape"
        case "png", "jpg", "jpeg", "gif", "svg", "ico": return "photo"
        case "sh", "zsh", "bash": return "terminal"
        case "css", "scss": return "paintbrush"
        case "html": return "globe"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "rb": return "diamond"
        case "go": return "chevron.left.forwardslash.chevron.right"
        case "rs": return "gearshape.2"
        case "lock": return "lock"
        case "gitignore", "gitmodules", "gitattributes": return "arrow.triangle.branch"
        default: return "doc"
        }
    }
}
