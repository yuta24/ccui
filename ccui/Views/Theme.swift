import SwiftUI

// MARK: - NSColor Tokens (AppKit layer — adaptive semantic colors)

extension NSColor {
    static let surfaceWindowColor = NSColor.windowBackgroundColor
    static let surfacePrimaryColor = NSColor.controlBackgroundColor
    static let textPrimaryColor = NSColor.labelColor
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

    // Accent — amber (Color.accent is auto-generated from AccentColor asset)
    static let accentSubtle = Color.accent.opacity(0.12)
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

    // Gutter
    static let gutterBg = Color.primary.opacity(0.02)
    static let gutterText = Color.primary.opacity(0.20)
}

// MARK: - Font Tokens

extension Font {
    static let monoBody = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.callout, design: .monospaced)
    static let monoCaption = Font.system(.subheadline, design: .monospaced)

    static let uiTitle = Font.headline
    static let uiLabel = Font.body
    static let uiCaption = Font.subheadline
    static let uiCaptionMono = Font.system(.subheadline, design: .monospaced)
}

// MARK: - Panel Metrics

enum PanelMetrics {
    static let cornerRadius: CGFloat = 8
    static let itemCornerRadius: CGFloat = 5
    static let panelCornerRadius: CGFloat = 10
    static let panelGap: CGFloat = 0
    static let windowEdgeInset: CGFloat = 0
    static let titleBarHeight: CGFloat = 28
    static let toolbarHeight: CGFloat = 32
}

// MARK: - View Modifiers

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
    func elevatedPanel() -> some View { modifier(ElevatedPanel()) }
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
