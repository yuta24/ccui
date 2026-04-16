import SwiftUI

// MARK: - NSColor Tokens

extension NSColor {
    static let surfaceWindowColor = NSColor(red: 0.027, green: 0.027, blue: 0.027, alpha: 1)
    static let surfacePrimaryColor = NSColor(red: 0.098, green: 0.098, blue: 0.098, alpha: 1)
    static let textPrimaryColor = NSColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 1)
    static let accentAmberColor = NSColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1)
    static let accentMutedColor = NSColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.25)
}

// MARK: - Color Tokens

extension Color {
    // Backgrounds
    static let surfaceWindow = Color(nsColor: .surfaceWindowColor)
    static let surfaceBase = Color(nsColor: NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1))
    static let surfacePrimary = Color(nsColor: .surfacePrimaryColor)
    static let surfaceElevated = Color(nsColor: NSColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1))
    static let surfaceHover = Color(nsColor: NSColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1))

    // Borders
    static let borderSubtle = Color.white.opacity(0.06)
    static let borderDefault = Color.white.opacity(0.10)
    static let borderStrong = Color.white.opacity(0.16)

    // Text
    static let textPrimary = Color(nsColor: .textPrimaryColor)
    static let textSecondary = Color(nsColor: NSColor(red: 0.53, green: 0.53, blue: 0.53, alpha: 1))
    static let textTertiary = Color(nsColor: NSColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1))

    // Accent - Amber
    static let accent = Color(nsColor: .accentAmberColor)
    static let accentSubtle = Color(nsColor: NSColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.12))
    static let accentMuted = Color(nsColor: .accentMutedColor)

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
    static let gutterBg = Color.white.opacity(0.02)
    static let gutterText = Color.white.opacity(0.20)
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
    static let panelGap: CGFloat = 3
    static let windowEdgeInset: CGFloat = 4
    static let titleBarHeight: CGFloat = 28
    static let toolbarHeight: CGFloat = 32

    /// Creates an AppKit floating panel container: outer (window bg + shadow + gap) → inner (rounded, bordered).
    /// Returns `(outer, panel)` — add content as subviews of `panel`.
    static func makeFloatingPanel() -> (outer: NSView, panel: NSView) {
        let outer = NSView()
        outer.wantsLayer = true
        outer.layer?.backgroundColor = NSColor.surfaceWindowColor.cgColor

        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.cornerRadius = panelCornerRadius
        panel.layer?.masksToBounds = true
        panel.layer?.backgroundColor = NSColor.surfacePrimaryColor.cgColor
        panel.layer?.borderWidth = 0.5
        panel.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor

        // Shadow on a wrapper to avoid masksToBounds clipping it
        let shadowHost = NSView()
        shadowHost.wantsLayer = true
        shadowHost.shadow = NSShadow()
        shadowHost.layer?.shadowColor = NSColor.black.withAlphaComponent(0.5).cgColor
        shadowHost.layer?.shadowOpacity = 1
        shadowHost.layer?.shadowRadius = 10
        shadowHost.layer?.shadowOffset = CGSize(width: 0, height: -2)
        shadowHost.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(shadowHost)

        panel.translatesAutoresizingMaskIntoConstraints = false
        shadowHost.addSubview(panel)

        NSLayoutConstraint.activate([
            shadowHost.topAnchor.constraint(equalTo: outer.topAnchor, constant: panelGap),
            shadowHost.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: panelGap),
            shadowHost.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -panelGap),
            shadowHost.bottomAnchor.constraint(equalTo: outer.bottomAnchor, constant: -panelGap),

            panel.topAnchor.constraint(equalTo: shadowHost.topAnchor),
            panel.leadingAnchor.constraint(equalTo: shadowHost.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: shadowHost.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: shadowHost.bottomAnchor),
        ])

        return (outer, panel)
    }
}

// MARK: - View Modifiers

struct FloatingPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.panelCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PanelMetrics.panelCornerRadius)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 2)
            .padding(PanelMetrics.panelGap)
            .background(Color.surfaceWindow)
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
    func floatingPanel() -> some View { modifier(FloatingPanel()) }
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
