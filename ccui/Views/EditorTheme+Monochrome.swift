import AppKit
import CodeEditSourceEditor

extension EditorTheme {
    static var monochrome: EditorTheme {
        let primary = NSColor.textPrimaryColor.resolvedRGB
        let secondary = NSColor.textSecondaryColor.resolvedRGB
        let tertiary = NSColor.textTertiaryColor.resolvedRGB
        let accent = NSColor.accentAmberColor.resolvedRGB

        return EditorTheme(
            text: .init(color: primary),
            insertionPoint: accent,
            invisibles: .init(color: tertiary),
            background: NSColor.surfacePrimaryColor.resolvedRGB,
            lineHighlight: primary.withAlphaComponent(0.05),
            selection: NSColor.accentMutedColor.resolvedRGB,
            keywords: .init(color: accent, bold: true),
            commands: .init(color: secondary),
            types: .init(color: accent),
            attributes: .init(color: secondary),
            variables: .init(color: primary),
            values: .init(color: secondary),
            numbers: .init(color: accent),
            strings: .init(color: secondary, italic: true),
            characters: .init(color: secondary),
            comments: .init(color: tertiary, italic: true)
        )
    }
}
