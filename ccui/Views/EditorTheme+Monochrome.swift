import AppKit
import CodeEditSourceEditor

extension EditorTheme {
    /// `resolvedRGB` の `usingColorSpace(.deviceRGB)` はその時点の
    /// `NSAppearance.currentDrawing()` を基準に dynamic な NSColor を解決するため、
    /// 通常のコンテキスト（SwiftUI の body 評価など）から呼ぶと常に `.aqua` 基準で
    /// 解決されてしまい、ダークモードでも明色のテーマになってしまう。
    /// アプリの実際の外観を current drawing appearance として明示的に設定してから解決する。
    static var monochrome: EditorTheme {
        var theme: EditorTheme!
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let primary = NSColor.textPrimaryColor.resolvedRGB
            let secondary = NSColor.textSecondaryColor.resolvedRGB
            let tertiary = NSColor.textTertiaryColor.resolvedRGB
            let accent = NSColor.accentAmberColor.resolvedRGB

            theme = EditorTheme(
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
        return theme
    }
}
