import AppKit
import CodeEditSourceEditor

extension EditorTheme {
    static var monochromeDark: EditorTheme {
        let lineHighlightColor = NSColor.white.withAlphaComponent(0.04)

        return EditorTheme(
            text: .init(color: NSColor.textPrimaryColor.resolvedRGB),
            insertionPoint: NSColor.accentAmberColor.resolvedRGB,
            invisibles: .init(color: NSColor.white.withAlphaComponent(0.15)),
            background: NSColor.surfacePrimaryColor.resolvedRGB,
            lineHighlight: lineHighlightColor,
            selection: NSColor.accentMutedColor.resolvedRGB,
            keywords: .init(color: NSColor.accentAmberColor.resolvedRGB, bold: true),
            commands: .init(color: NSColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1)),
            types: .init(color: NSColor(red: 0.85, green: 0.60, blue: 0.20, alpha: 1)),
            attributes: .init(color: NSColor(red: 0.70, green: 0.70, blue: 0.70, alpha: 1)),
            variables: .init(color: NSColor.textPrimaryColor.resolvedRGB),
            values: .init(color: NSColor(red: 0.82, green: 0.82, blue: 0.82, alpha: 1)),
            numbers: .init(color: NSColor(red: 0.90, green: 0.60, blue: 0.20, alpha: 1)),
            strings: .init(color: NSColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1), italic: true),
            characters: .init(color: NSColor(red: 0.80, green: 0.80, blue: 0.80, alpha: 1)),
            comments: .init(color: NSColor.white.withAlphaComponent(0.30), italic: true)
        )
    }
}

private extension NSColor {
    /// CodeEditSourceEditor は `EditorTheme` の色に対して `.brightnessComponent` などの
    /// RGBコンポーネントへ直接アクセスする（例: MinimapView.setTheme）。labelColor や
    /// controlBackgroundColor、アセットカラーのような dynamic/catalog な NSColor は
    /// 変換せずにアクセスすると例外を投げてクラッシュするため、deviceRGB に解決してから渡す。
    var resolvedRGB: NSColor {
        usingColorSpace(.deviceRGB) ?? self
    }
}
