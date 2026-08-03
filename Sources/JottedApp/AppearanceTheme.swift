import AppKit
import SwiftUI

/// The user-selectable visual character of Jotted.
///
/// A theme is an *accent identity*, not a paint job. The board surface stays
/// neutral glass in every theme; the accent shows up on the completion ring,
/// section headings, counts, controls and selection states, plus a short glow
/// bleeding down from the top edge. That is how the system's own list apps
/// carry a colour, and it leaves the panel actually translucent instead of
/// hiding the desktop behind a sheet of gradient.
///
/// Accents are Apple's semantic system colours, so they track light/dark,
/// Increase Contrast and any future system palette revision for free.
enum AppearanceTheme: String, CaseIterable, Identifiable, Sendable {
    case graphite
    case aurora
    case blossom
    case amber
    case abyss

    static let preferenceKey = "JottedAppearanceTheme"
    static let defaultTheme: AppearanceTheme = .graphite

    /// Raw values used before the 1.8 palette rebuild.
    private static let legacyRawValues: [String: AppearanceTheme] = [
        "silver": .graphite,
        "prism": .aurora,
        "sakura": .blossom,
        "oak": .amber,
        "neon-noir": .abyss
    ]

    var id: String { rawValue }

    var localizationKey: L10n.Key {
        switch self {
        case .graphite: .themeGraphite
        case .aurora: .themeAurora
        case .blossom: .themeBlossom
        case .amber: .themeAmber
        case .abyss: .themeAbyss
        }
    }

    static func selected(in defaults: UserDefaults = .standard) -> AppearanceTheme {
        guard let rawValue = defaults.string(forKey: preferenceKey) else {
            return defaultTheme
        }
        if let theme = AppearanceTheme(rawValue: rawValue) {
            return theme
        }
        if let migrated = legacyRawValues[rawValue] {
            defaults.set(migrated.rawValue, forKey: preferenceKey)
            return migrated
        }
        return defaultTheme
    }

    /// Rewrites a stored legacy identifier so `@AppStorage` bindings observe the
    /// new value instead of silently falling back to the default theme.
    static func migrateStoredPreferenceIfNeeded(defaults: UserDefaults = .standard) {
        guard let rawValue = defaults.string(forKey: preferenceKey),
              AppearanceTheme(rawValue: rawValue) == nil,
              let migrated = legacyRawValues[rawValue] else {
            return
        }
        defaults.set(migrated.rawValue, forKey: preferenceKey)
    }

    // MARK: - Accent

    /// The theme's identity colour.
    ///
    /// Deliberately *not* an Apple system colour. `systemRed`, `systemIndigo`
    /// and friends are tuned for opaque controls: at the saturation they carry
    /// they sit on top of frosted glass rather than inside it, and they fight
    /// whatever wallpaper shows through once the panel goes translucent. These
    /// are low-chroma equivalents — around a third of the saturation, with the
    /// value pushed dark enough in light mode and light enough in dark mode to
    /// hold contrast against a moving backdrop.
    func accent(for scheme: ColorScheme) -> Color {
        switch (self, scheme) {
        case (.graphite, .dark): Color(red: 0.663, green: 0.682, blue: 0.706)
        case (.graphite, _): Color(red: 0.412, green: 0.427, blue: 0.447)

        // Red pulled well below green so the hue lands in blue rather than
        // blue-violet, and darkened in light appearance for depth.
        case (.aurora, .dark): Color(red: 0.545, green: 0.678, blue: 0.847)
        case (.aurora, _): Color(red: 0.235, green: 0.376, blue: 0.588)

        case (.blossom, .dark): Color(red: 0.855, green: 0.667, blue: 0.686)
        case (.blossom, _): Color(red: 0.667, green: 0.463, blue: 0.494)

        case (.amber, .dark): Color(red: 0.831, green: 0.741, blue: 0.573)
        case (.amber, _): Color(red: 0.616, green: 0.510, blue: 0.341)

        case (.abyss, .dark): Color(red: 0.596, green: 0.749, blue: 0.722)
        case (.abyss, _): Color(red: 0.337, green: 0.518, blue: 0.494)
        }
    }

    /// A neighbouring hue, used only to give the top glow a faint iridescence
    /// instead of a flat single-colour fade.
    func companion(for scheme: ColorScheme) -> Color {
        switch (self, scheme) {
        case (.graphite, .dark): Color(red: 0.600, green: 0.639, blue: 0.686)
        case (.graphite, _): Color(red: 0.451, green: 0.478, blue: 0.514)

        case (.aurora, .dark): Color(red: 0.573, green: 0.792, blue: 0.831)
        case (.aurora, _): Color(red: 0.286, green: 0.510, blue: 0.612)

        case (.blossom, .dark): Color(red: 0.882, green: 0.749, blue: 0.667)
        case (.blossom, _): Color(red: 0.706, green: 0.545, blue: 0.451)

        case (.amber, .dark): Color(red: 0.741, green: 0.784, blue: 0.635)
        case (.amber, _): Color(red: 0.529, green: 0.573, blue: 0.412)

        case (.abyss, .dark): Color(red: 0.596, green: 0.694, blue: 0.808)
        case (.abyss, _): Color(red: 0.361, green: 0.463, blue: 0.588)
        }
    }

    /// Graphite reads as "no colour", so glows and tints are suppressed for it.
    var isChromatic: Bool { self != .graphite }

    // MARK: - Surface treatment

    /// Opacity of the short accent glow that bleeds down from the top edge.
    /// Small on purpose: it should register as light caught in the glass,
    /// never as a background.
    func topGlowOpacity(for scheme: ColorScheme) -> Double {
        guard isChromatic else { return 0 }
        return scheme == .dark ? 0.24 : 0.20
    }

    /// Tint fed to the Liquid Glass material. Liquid Glass tints are meant to
    /// be barely-there; anything stronger turns the material into paint.
    func glassTint(for scheme: ColorScheme) -> Color? {
        guard isChromatic else { return nil }
        return accent(for: scheme).opacity(scheme == .dark ? 0.12 : 0.09)
    }

    /// Accent strength on the row separators and panel border.
    func hairlineOpacity(for scheme: ColorScheme) -> Double {
        if !isChromatic {
            return scheme == .dark ? 0.10 : 0.09
        }
        return scheme == .dark ? 0.22 : 0.20
    }

    // MARK: - Legacy compatibility

    /// Retained for the theme gallery and the settings swatches, which render
    /// a small chip rather than a full panel.
    func ambientColors(for scheme: ColorScheme) -> [Color] {
        [accent(for: scheme), companion(for: scheme)]
    }

    func washColors(for scheme: ColorScheme) -> [Color] {
        ambientColors(for: scheme)
    }

    func boardAmbientOpacity(for scheme: ColorScheme) -> Double {
        topGlowOpacity(for: scheme)
    }

    func boardWashOpacity(for scheme: ColorScheme) -> Double {
        topGlowOpacity(for: scheme)
    }

    func rowAmbientOpacity(for scheme: ColorScheme) -> Double { 0 }

    func floatingAmbientOpacity(for scheme: ColorScheme) -> Double {
        topGlowOpacity(for: scheme)
    }

    var decorativeHighlightMultiplier: Double { 1 }

    var rowHighlightMultiplier: Double { 1 }
}

/// Convenience values for `@AppStorage`, kept separate from the enum so a
/// settings control can bind directly to the persisted raw string.
enum AppearanceThemePreference {
    static let key = AppearanceTheme.preferenceKey
    static let defaultValue = AppearanceTheme.defaultTheme.rawValue

    static func current(defaults: UserDefaults = .standard) -> AppearanceTheme {
        AppearanceTheme.selected(in: defaults)
    }
}

/// A semantic palette.
///
/// Every entry is a dynamic system colour, so the light and dark slots hold
/// the same value. The pairs survive only because a number of call sites ask
/// for one appearance explicitly; they resolve identically now.
struct JottedThemePalette {
    let accentLight: Color
    let accentDark: Color
    let filledAccentLight: Color
    let filledAccentDark: Color
    let panelTintLight: Color
    let panelTintDark: Color
    let controlFillLight: Color
    let controlFillDark: Color
    let controlForegroundLight: Color
    let controlForegroundDark: Color
    let rowFillLight: Color
    let rowFillDark: Color
    let rowHoverLight: Color
    let rowHoverDark: Color
    let rowBorderLight: Color
    let rowBorderDark: Color
    let successLight: Color
    let successDark: Color
    let warningLight: Color
    let warningDark: Color
    let dangerLight: Color
    let dangerDark: Color
    let neutralLight: Color
    let neutralDark: Color
}

extension AppearanceTheme {
    var palette: JottedThemePalette {
        JottedThemePalette(
            accentLight: accent(for: .light),
            accentDark: accent(for: .dark),
            filledAccentLight: accent(for: .light),
            filledAccentDark: accent(for: .dark),
            panelTintLight: Color(nsColor: .windowBackgroundColor),
            panelTintDark: Color(nsColor: .windowBackgroundColor),
            controlFillLight: Color.primary.opacity(0.055),
            controlFillDark: Color.primary.opacity(0.085),
            controlForegroundLight: Color(nsColor: .labelColor),
            controlForegroundDark: Color(nsColor: .labelColor),
            rowFillLight: Color.clear,
            rowFillDark: Color.clear,
            rowHoverLight: Color.primary.opacity(0.05),
            rowHoverDark: Color.primary.opacity(0.08),
            rowBorderLight: Color(nsColor: .separatorColor),
            rowBorderDark: Color(nsColor: .separatorColor),
            // Status colours are muted to the same degree as the accents. A
            // system-red "overdue" label next to a dusty accent looked like an
            // alert pasted onto the panel.
            successLight: Color(red: 0.369, green: 0.549, blue: 0.435),
            successDark: Color(red: 0.588, green: 0.761, blue: 0.651),
            warningLight: Color(red: 0.659, green: 0.510, blue: 0.243),
            warningDark: Color(red: 0.847, green: 0.706, blue: 0.447),
            dangerLight: Color(red: 0.706, green: 0.329, blue: 0.361),
            dangerDark: Color(red: 0.878, green: 0.565, blue: 0.596),
            // Opaque on purpose. `secondaryLabelColor` is semi-transparent, so
            // over a translucent panel it composites straight onto the
            // wallpaper and loses most of its contrast.
            neutralLight: Color(red: 0.337, green: 0.345, blue: 0.365),
            neutralDark: Color(red: 0.729, green: 0.741, blue: 0.765)
        )
    }
}
