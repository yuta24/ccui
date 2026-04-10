import AppKit
import CodeEditSourceEditor

extension EditorTheme {
    static var monochromeDark: EditorTheme {
        let lineHighlightColor = NSColor.white.withAlphaComponent(0.04)

        return EditorTheme(
            text: .init(color: .textPrimaryColor),
            insertionPoint: .accentAmberColor,
            invisibles: .init(color: NSColor.white.withAlphaComponent(0.15)),
            background: .surfacePrimaryColor,
            lineHighlight: lineHighlightColor,
            selection: .accentMutedColor,
            keywords: .init(color: .accentAmberColor, bold: true),
            commands: .init(color: NSColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1)),
            types: .init(color: NSColor(red: 0.85, green: 0.60, blue: 0.20, alpha: 1)),
            attributes: .init(color: NSColor(red: 0.70, green: 0.70, blue: 0.70, alpha: 1)),
            variables: .init(color: .textPrimaryColor),
            values: .init(color: NSColor(red: 0.82, green: 0.82, blue: 0.82, alpha: 1)),
            numbers: .init(color: NSColor(red: 0.90, green: 0.60, blue: 0.20, alpha: 1)),
            strings: .init(color: NSColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1), italic: true),
            characters: .init(color: NSColor(red: 0.80, green: 0.80, blue: 0.80, alpha: 1)),
            comments: .init(color: NSColor.white.withAlphaComponent(0.30), italic: true)
        )
    }
}
