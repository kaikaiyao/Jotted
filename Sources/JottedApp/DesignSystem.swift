import AppKit
import SwiftUI

enum JottedLayout {
    static let windowInset: CGFloat = 16
    static let cardWidth: CGFloat = 372
    static let expandedCardHeight: CGFloat = 540
    static let minimumCardWidth: CGFloat = 248
    static let minimumExpandedCardHeight: CGFloat = 188
    static let maximumCardWidth: CGFloat = 520
    static let maximumCardHeight: CGFloat = 780

    /// Outer board radius. Inner surfaces derive from it so corners stay
    /// concentric the way the platform expects.
    static let boardCornerRadius: CGFloat = 26
    static let rowCornerRadius: CGFloat = 12

    static let condensedEntryWindowSize = NSSize(width: 352, height: 332)
    static let fullReturnWindowSize = NSSize(width: 376, height: 368)
    static let taskEditorWindowSize = NSSize(width: 392, height: 410)
    static let settingsWindowSize = NSSize(width: 416, height: 348)
    static let settingsPanelSize = NSSize(width: 360, height: 292)
    static let themeGallerySize = NSSize(width: 800, height: 300)

    static var defaultWindowSize: NSSize {
        NSSize(
            width: cardWidth + windowInset * 2,
            height: expandedCardHeight + windowInset * 2
        )
    }

    static var minimumWindowWidth: CGFloat {
        minimumCardWidth + windowInset * 2
    }

    static var minimumExpandedWindowHeight: CGFloat {
        minimumExpandedCardHeight + windowInset * 2
    }

    static var minimumExpandedWindowSize: NSSize {
        NSSize(width: minimumWindowWidth, height: minimumExpandedWindowHeight)
    }

    static var maximumWindowSize: NSSize {
        NSSize(
            width: maximumCardWidth + windowInset * 2,
            height: maximumCardHeight + windowInset * 2
        )
    }
}

enum JottedPalette {
    private static var theme: AppearanceTheme {
        AppearanceThemePreference.current()
    }

    private static var palette: JottedThemePalette {
        theme.palette
    }

    // Compatibility accessors retained for existing call sites that explicitly
    // need a light- or dark-appearance color.
    static var accent: Color { palette.accentLight }
    static var accentDark: Color { palette.accentDark }
    static var filledAccent: Color { palette.filledAccentLight }
    static var filledAccentDark: Color { palette.filledAccentDark }

    static var success: Color { palette.successLight }
    static var successDark: Color { palette.successDark }
    static var warning: Color { palette.warningLight }
    static var warningDark: Color { palette.warningDark }
    static var danger: Color { palette.dangerLight }
    static var dangerDark: Color { palette.dangerDark }
    static var neutral: Color { palette.neutralLight }
    static var neutralDark: Color { palette.neutralDark }

    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? accentDark : accent
    }

    static func filledAccent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? filledAccentDark : filledAccent
    }

    static func success(for scheme: ColorScheme) -> Color {
        scheme == .dark ? successDark : success
    }

    static func warning(for scheme: ColorScheme) -> Color {
        scheme == .dark ? warningDark : warning
    }

    static func danger(for scheme: ColorScheme) -> Color {
        scheme == .dark ? dangerDark : danger
    }

    static func neutral(for scheme: ColorScheme) -> Color {
        scheme == .dark ? neutralDark : neutral
    }

    static func panelTint(for scheme: ColorScheme) -> Color {
        scheme == .dark ? palette.panelTintDark : palette.panelTintLight
    }

    static func controlFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? palette.controlFillDark : palette.controlFillLight
    }

    static func controlForeground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? palette.controlForegroundDark : palette.controlForegroundLight
    }

    static func rowFill(for scheme: ColorScheme, hovering: Bool) -> Color {
        switch (scheme, hovering) {
        case (.dark, true): palette.rowHoverDark
        case (.dark, false): palette.rowFillDark
        case (_, true): palette.rowHoverLight
        case (_, false): palette.rowFillLight
        }
    }

    static func rowBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? palette.rowBorderDark : palette.rowBorderLight
    }

    static func ambientColors(for scheme: ColorScheme) -> [Color] {
        theme.ambientColors(for: scheme)
    }

    /// Halo drawn behind text so it stays legible once the glass is thin
    /// enough for the desktop to read through. Always the opposite luminance
    /// to the text, never a hue — hue would just be one more colour that can
    /// clash with the wallpaper.
    static func legibilityHalo(
        for scheme: ColorScheme,
        transparency: Double,
        reduceTransparency: Bool
    ) -> Color {
        guard !reduceTransparency else { return .clear }
        let opacity = GlassTransparencyPreference.legibilityHaloOpacity(value: transparency)
        return (scheme == .dark ? Color.black : Color.white).opacity(opacity)
    }

    /// Quiets a colour without turning it grey, so a control at rest can still
    /// belong to the theme instead of defaulting to neutral.
    static func quieted(_ color: Color, by amount: Double) -> Color {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return color }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        srgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return Color(
            nsColor: NSColor(
                hue: hue,
                saturation: saturation * CGFloat(1 - min(max(amount, 0), 1)),
                brightness: brightness,
                alpha: alpha
            )
        )
    }

    /// Deepens a colour as the glass thins, without changing what colour it is.
    ///
    /// The halo alone is not enough for secondary text: a mid-tone label with
    /// a white halo still has little contrast of its own, so on a bright
    /// wallpaper the glyph and its halo converge.
    ///
    /// The obvious fix — mixing toward black — also drains the hue, which
    /// would leave every theme with the same near-black deadline text. So the
    /// adjustment happens in HSB with the hue pinned: in light appearance the
    /// colour goes darker *and* more saturated, in dark appearance lighter and
    /// slightly calmer. Contrast rises, identity survives.
    static func legible(
        _ color: Color,
        for scheme: ColorScheme,
        legibility: Double
    ) -> Color {
        let factor = min(max(legibility, 0), 1)
        guard factor > 0,
              let srgb = NSColor(color).usingColorSpace(.sRGB) else {
            return color
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        srgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let adjustedSaturation: CGFloat
        let adjustedBrightness: CGFloat
        if scheme == .dark {
            adjustedSaturation = saturation * (1 - 0.15 * factor)
            adjustedBrightness = brightness + (1 - brightness) * 0.5 * factor
        } else {
            adjustedSaturation = min(saturation * (1 + 0.55 * factor), 1)
            adjustedBrightness = brightness * (1 - 0.40 * factor)
        }

        return Color(
            nsColor: NSColor(
                hue: hue,
                saturation: adjustedSaturation,
                brightness: adjustedBrightness,
                alpha: alpha
            )
        )
    }
}

extension View {
    /// Applies the legibility halo. Three passes at increasing radii: a tight
    /// one that thickens the glyph edge, a middle one for density, and a wide
    /// one that lifts the text off busy backgrounds such as foliage.
    func legibilityHalo(_ color: Color) -> some View {
        shadow(color: color, radius: 1)
            .shadow(color: color, radius: 2.5)
            .shadow(color: color, radius: 5)
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var alpha: CGFloat = 1

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.alphaValue = alpha
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.alphaValue = alpha
    }
}

/// A short accent glow bleeding down from the top edge of a surface.
///
/// This replaces the old full-panel diagonal wash. Painting the whole card
/// made every theme read as a coloured sheet — cheap-looking, and opaque
/// enough to defeat the transparency setting. A glow anchored to the top edge
/// carries the theme while leaving the rest of the panel as plain glass, which
/// is how the system's own list apps handle a list colour.
///
/// Also blur-free: the previous implementation ran `.blur(radius:)` over
/// stacked radial gradients, forcing an offscreen render pass per instance.
struct ThemeAmbientWash: View {
    let theme: AppearanceTheme
    let colorScheme: ColorScheme
    /// Ignored. Retained so existing call sites keep compiling.
    var blurRadius: CGFloat = 0
    /// How far down the glow reaches, as a fraction of the surface height.
    var reach: Double = 0.34

    var body: some View {
        // Two hues rather than one fading colour: the accent at the very top,
        // drifting through a neighbouring hue before it clears. That slight
        // shift is what reads as light refracting in glass instead of a flat
        // coloured band.
        LinearGradient(
            stops: [
                .init(color: theme.accent(for: colorScheme), location: 0),
                .init(color: theme.companion(for: colorScheme).opacity(0.62), location: reach * 0.42),
                .init(color: theme.companion(for: colorScheme).opacity(0.18), location: reach * 0.72),
                .init(color: .clear, location: reach)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}


struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableNSView {
        DraggableNSView()
    }

    func updateNSView(_ nsView: DraggableNSView, context: Context) {}
}

final class DraggableNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // The drag surface is transparent to right-clicks and scrolling so the
        // board menu and task list continue to receive those events.
        guard NSApp.currentEvent?.type == .leftMouseDown else { return nil }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override var mouseDownCanMoveWindow: Bool { true }
}

struct IconButton: View {
    let systemName: String
    let label: String
    var isProminent = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    isProminent
                        ? Color.white.opacity(0.96)
                        : JottedPalette.controlForeground(for: colorScheme).opacity(0.9)
                )
                .frame(width: 30, height: 30)
                .jottedGlass(
                    in: Circle(),
                    tint: isProminent
                        ? JottedPalette.filledAccent(for: colorScheme)
                        : nil,
                    interactive: true
                ) {
                    Circle()
                        .fill(
                            isProminent
                                ? JottedPalette.filledAccent(for: colorScheme)
                                : JottedPalette.controlFill(for: colorScheme)
                        )
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    Color.white.opacity(
                                        isProminent ? 0.40 : (colorScheme == .dark ? 0.13 : 0.82)
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

struct CapsuleActionStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(
                configuration.isPressed
                    ? Color.primary
                    : JottedPalette.accent(for: colorScheme)
            )
            .padding(.horizontal, 12)
            .frame(height: 28)
            .jottedGlass(in: Capsule(style: .continuous), interactive: true) {
                Capsule(style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? JottedPalette.accent(for: colorScheme)
                                .opacity(colorScheme == .dark ? 0.22 : 0.11)
                            : JottedPalette.controlFill(for: colorScheme)
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.12)
                                    : Color.white.opacity(0.82),
                                lineWidth: 0.7
                            )
                    }
            }
            .contentShape(Capsule(style: .continuous))
    }
}
