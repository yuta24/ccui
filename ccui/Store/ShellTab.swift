import AppKit
import SwiftUI

@Observable
@MainActor
final class ShellTab: Identifiable {
    let id: UUID
    var title: String
    let session: any TerminalSession

    init(worktreePath: String, shellPath: String = AppSettings.defaultShellPath, additionalEnvironment: [String] = [], font: NSFont? = nil) {
        let id = UUID()
        self.id = id
        self.title = "Shell"
        let session = SwiftTermSession(
            workingDirectory: worktreePath,
            label: "Shell",
            executable: shellPath,
            args: ["-l"],
            additionalEnvironment: additionalEnvironment,
            font: font
        )
        self.session = session
        session.onTitleChanged = { [weak self] title in
            self?.title = title
        }
    }
}
