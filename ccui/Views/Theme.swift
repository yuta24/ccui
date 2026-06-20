import SwiftUI

// MARK: - NSColor Tokens (AppKit layer — adaptive semantic colors)

extension NSColor {
    /// CGColor やRGBコンポーネントへ直接アクセスする AppKit API (例: `layer.backgroundColor`,
    /// `.brightnessComponent`) は、labelColor や controlBackgroundColor のような
    /// dynamic/catalog な NSColor を変換せずに渡すと誤った色や例外になる場合があるため、
    /// deviceRGB に解決してから渡す。
    var resolvedRGB: NSColor {
        usingColorSpace(.deviceRGB) ?? self
    }

    static let surfaceWindowColor = NSColor.windowBackgroundColor
    static let surfacePrimaryColor = NSColor.controlBackgroundColor
    static let textPrimaryColor = NSColor.labelColor
    static let textSecondaryColor = NSColor.secondaryLabelColor
    static let textTertiaryColor = NSColor.tertiaryLabelColor
    static let accentAmberColor = NSColor(named: "AccentColor") ?? NSColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1)
    static let accentMutedColor = (NSColor(named: "AccentColor") ?? NSColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1))
        .withAlphaComponent(0.25)

    static let surfaceElevatedColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1)
            : NSColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1)
    }
}

// MARK: - Color Tokens (SwiftUI layer — adaptive)

extension Color {
    // Backgrounds
    static let surfaceWindow = Color(nsColor: .windowBackgroundColor)
    static let surfaceBase = Color(nsColor: .underPageBackgroundColor)
    static let surfacePrimary = Color(nsColor: .controlBackgroundColor)
    static let surfaceElevated = Color(nsColor: .surfaceElevatedColor)
    static let surfaceHover = Color.primary.opacity(0.06)

    // Borders
    static let borderSubtle = Color.primary.opacity(0.06)
    static let borderDefault = Color.primary.opacity(0.10)
    static let borderStrong = Color.primary.opacity(0.16)

    // Text
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    /// Contrasting text for solid accent/textPrimary-colored backgrounds (inverse of textPrimary).
    static let textInverted = Color(nsColor: .windowBackgroundColor)

    // Accent — amber (Color.accent is auto-generated from AccentColor asset)
    static let accentSubtle = Color.accent.opacity(0.18)
    static let accentMuted = Color.accent.opacity(0.25)

    // Semantic
    static let diffAddition = Color(nsColor: NSColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1))
    static let diffAdditionBg = Color(nsColor: NSColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 0.08))
    static let diffDeletion = Color(nsColor: NSColor(red: 0.94, green: 0.33, blue: 0.31, alpha: 1))
    static let diffDeletionBg = Color(nsColor: NSColor(red: 0.94, green: 0.33, blue: 0.31, alpha: 0.08))
    static let statusClean = Color(nsColor: NSColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1))
    static let statusRenamed = Color(nsColor: NSColor(red: 0.26, green: 0.65, blue: 0.96, alpha: 1))

    // Intervention
    static let interventionColor = Color(nsColor: NSColor(red: 0.67, green: 0.44, blue: 0.96, alpha: 1))
    static let interventionSubtle = Color(nsColor: NSColor(red: 0.67, green: 0.44, blue: 0.96, alpha: 0.12))

    // Warning
    static let statusWarning = Color(nsColor: .systemOrange)
    static let statusWarningBg = Color(nsColor: .systemOrange).opacity(0.10)

    // Gutter
    static let gutterBg = Color.primary.opacity(0.02)
    static let gutterText = Color.primary.opacity(0.20)
}

// MARK: - Font Tokens

extension Font {
    static let monoBody = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.callout, design: .monospaced)
    static let monoCaption = Font.system(.subheadline, design: .monospaced)
    static let monoBadge = Font.system(size: 9, weight: .bold, design: .monospaced)
    static let monoDetail = Font.system(size: 10, design: .monospaced)
    static let monoField = Font.system(size: 12, design: .monospaced)

    static let uiTitle = Font.headline
    static let uiLabel = Font.body
    static let uiCaption = Font.subheadline
    static let uiCaptionMono = Font.system(.subheadline, design: .monospaced)

    static let iconMicro = Font.system(size: 7, weight: .medium)
    static let iconTiny = Font.system(size: 8, weight: .semibold)
    static let iconSmall = Font.system(size: 9, weight: .medium)
    static let iconDefault = Font.system(size: 10, weight: .medium)
    static let iconMedium = Font.system(size: 11, weight: .medium)
    static let iconLarge = Font.system(size: 12, weight: .medium)

    static let emptyStateIcon = Font.system(size: 28, weight: .ultraLight)
    static let emptyStateIconLarge = Font.system(size: 36, weight: .ultraLight)
}

// MARK: - Code Font Environment Key

private struct CodeFontKey: EnvironmentKey {
    static let defaultValue = Font.system(.subheadline, design: .monospaced)
}

extension EnvironmentValues {
    var codeFont: Font {
        get { self[CodeFontKey.self] }
        set { self[CodeFontKey.self] = newValue }
    }
}

// MARK: - Panel Metrics

enum PanelMetrics {
    static let cornerRadius: CGFloat = 8
    static let itemCornerRadius: CGFloat = 5
    static let panelCornerRadius: CGFloat = 10
    static let panelGap: CGFloat = 0
    static let windowEdgeInset: CGFloat = 0
    static let titleBarHeight: CGFloat = 28

    static let badgeCornerRadius: CGFloat = 3
    static let buttonCornerRadius: CGFloat = 4
    static let inputCornerRadius: CGFloat = 6

    static let badgeSize: CGFloat = 16

    // ContentControlsBar (titlebar accessory: layout split / inspector / configuration)
    static let contentControlCornerRadius: CGFloat = 6
    static let contentControlButtonSize: CGFloat = 24
    static let contentControlSpacing: CGFloat = 4
    /// Accessory width for the max case (3 buttons), used as the fixed NSHostingView frame width
    /// since NSTitlebarAccessoryViewController doesn't size correctly via `.intrinsicContentSize`.
    static let contentControlsAccessoryWidth: CGFloat =
        3 * contentControlButtonSize + 2 * contentControlSpacing + windowEdgeInset + 10
}

// MARK: - Opacity Tokens

enum Opacity {
    static let badgeBg: Double = 0.12
    static let subtleOverlay: Double = 0.15
    static let dimmed: Double = 0.4
    static let mutedAccent: Double = 0.7
}

// MARK: - View Modifiers

struct ElevatedPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(in: .rect(cornerRadius: 6))
    }
}

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = PanelMetrics.panelCornerRadius
    func body(content: Content) -> some View {
        content
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
    }
}

struct SectionHeader: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.uiCaption)
            .foregroundStyle(Color.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

extension View {
    func elevatedPanel() -> some View { modifier(ElevatedPanel()) }
    func glassPanel(cornerRadius: CGFloat = PanelMetrics.panelCornerRadius) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }
    func sectionHeader() -> some View { modifier(SectionHeader()) }
}

// MARK: - Hover Scale Button Style

struct HoverScaleButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : isHovered ? 1.08 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : isHovered ? 1.0 : 0.85)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension ButtonStyle where Self == HoverScaleButtonStyle {
    static var hoverScale: HoverScaleButtonStyle { HoverScaleButtonStyle() }
}

// MARK: - Tool Bar Color

extension Color {
    static func toolBarColor(for toolName: String) -> Color {
        switch toolName {
        case "Read": .statusRenamed
        case "Edit", "Write": .accent
        case "Bash": .diffAddition
        case "Grep", "Glob": .statusRenamed.opacity(0.7)
        default: .textTertiary
        }
    }
}

// MARK: - Diff Status Badge

struct DiffStatusBadge: View {
    let status: DiffFileEntry.Status

    var body: some View {
        let color = FileTreeHelpers.statusColor(status)
        Text(FileTreeHelpers.statusLetter(status))
            .font(.monoBadge)
            .foregroundStyle(color)
            .frame(width: PanelMetrics.badgeSize, height: PanelMetrics.badgeSize)
            .background(color.opacity(Opacity.badgeBg))
            .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.badgeCornerRadius))
    }
}

// MARK: - Pulsing Dots Loading Indicator

struct PulsingDotsView: View {
    let color: Color
    let dotSize: CGFloat
    let count: Int

    @State private var isAnimating = false

    init(color: Color = .accent, dotSize: CGFloat = 5, count: Int = 3) {
        self.color = color
        self.dotSize = dotSize
        self.count = count
    }

    var body: some View {
        HStack(spacing: dotSize * 0.8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(isAnimating ? 1.0 : 0.4)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}
