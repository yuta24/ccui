import SwiftUI

// MARK: - Color Tokens

extension Color {
    // Backgrounds
    static let surfaceBase = Color(nsColor: NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1))
    static let surfacePrimary = Color(nsColor: NSColor(red: 0.098, green: 0.098, blue: 0.098, alpha: 1))
    static let surfaceElevated = Color(nsColor: NSColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1))
    static let surfaceHover = Color(nsColor: NSColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1))

    // Borders
    static let borderSubtle = Color.white.opacity(0.06)
    static let borderDefault = Color.white.opacity(0.10)
    static let borderStrong = Color.white.opacity(0.16)

    // Text
    static let textPrimary = Color(nsColor: NSColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 1))
    static let textSecondary = Color(nsColor: NSColor(red: 0.53, green: 0.53, blue: 0.53, alpha: 1))
    static let textTertiary = Color(nsColor: NSColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1))

    // Accent - Amber
    static let accent = Color(nsColor: NSColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1))
    static let accentSubtle = Color(nsColor: NSColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.12))
    static let accentMuted = Color(nsColor: NSColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.25))

    // Semantic
    static let diffAddition = Color(nsColor: NSColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1))
    static let diffAdditionBg = Color(nsColor: NSColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 0.08))
    static let diffDeletion = Color(nsColor: NSColor(red: 0.94, green: 0.33, blue: 0.31, alpha: 1))
    static let diffDeletionBg = Color(nsColor: NSColor(red: 0.94, green: 0.33, blue: 0.31, alpha: 0.08))
    static let statusClean = Color(nsColor: NSColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1))
    static let statusRenamed = Color(nsColor: NSColor(red: 0.26, green: 0.65, blue: 0.96, alpha: 1))

    // Gutter
    static let gutterBg = Color.white.opacity(0.02)
    static let gutterText = Color.white.opacity(0.20)
}

// MARK: - Font Tokens

extension Font {
    static let monoBody = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.callout, design: .monospaced)
    static let monoCaption = Font.system(.caption, design: .monospaced)

    static let uiTitle = Font.system(size: 11, weight: .semibold).leading(.tight)
    static let uiLabel = Font.system(size: 11, weight: .medium)
    static let uiCaption = Font.system(size: 10, weight: .medium)
    static let uiCaptionMono = Font.system(size: 10, weight: .medium, design: .monospaced)
}

// MARK: - View Modifiers

struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.surfacePrimary)
    }
}

struct ElevatedPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.borderSubtle, lineWidth: 1)
            )
    }
}

struct SectionHeader: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.uiCaption)
            .foregroundStyle(Color.textTertiary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

extension View {
    func panelBackground() -> some View { modifier(PanelBackground()) }
    func elevatedPanel() -> some View { modifier(ElevatedPanel()) }
    func sectionHeader() -> some View { modifier(SectionHeader()) }
}
