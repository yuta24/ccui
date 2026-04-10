import AppKit

nonisolated struct ExternalEditor: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let bundleID: String

    private static let all: [ExternalEditor] = [
        ExternalEditor(id: "vscode", name: "Visual Studio Code", bundleID: "com.microsoft.VSCode"),
        ExternalEditor(id: "cursor", name: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92"),
        ExternalEditor(id: "zed", name: "Zed", bundleID: "dev.zed.Zed"),
    ]

    @MainActor
    static var installed: [ExternalEditor] {
        all.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil }
    }

    @MainActor
    func open(path: String) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }
}
