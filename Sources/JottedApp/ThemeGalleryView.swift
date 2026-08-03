import SwiftUI

/// A compact, language-aware contact sheet for the README. Every card uses
/// the production palette so the five themes can be compared under the same
/// wallpaper and in both system appearances.
struct ThemeGalleryView: View {
    @ObservedObject private var localization = AppLocalization.shared

    var body: some View {
        VStack(spacing: 8) {
            themeHeadings
            galleryRow(
                scheme: .light,
                label: localization.text(.lightMode),
                symbol: "sun.max.fill"
            )
            galleryRow(
                scheme: .dark,
                label: localization.text(.darkMode),
                symbol: "moon.stars.fill"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(
            width: JottedLayout.themeGallerySize.width,
            height: JottedLayout.themeGallerySize.height
        )
        .background(Color.clear)
    }

    private var themeHeadings: some View {
        HStack(spacing: 8) {
            Color.clear
                .frame(width: 58, height: 18)

            ForEach(AppearanceTheme.allCases) { theme in
                Text(localization.text(theme.localizationKey))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.205, green: 0.218, blue: 0.238))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
                    .background {
                        Capsule()
                            .fill(Color.white.opacity(0.88))
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.7)
                            }
                            .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                    }
            }
        }
        .frame(height: 22)
    }

    private func galleryRow(
        scheme: ColorScheme,
        label: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        scheme == .light
                            ? Color(red: 0.745, green: 0.545, blue: 0.205)
                            : Color(red: 0.690, green: 0.790, blue: 0.930)
                    )

                Text(label)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        scheme == .light
                            ? Color(red: 0.250, green: 0.260, blue: 0.275)
                            : Color.white.opacity(0.80)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: 58, height: 113)
            .background {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        scheme == .light
                            ? Color.white.opacity(0.88)
                            : Color(red: 0.075, green: 0.080, blue: 0.095).opacity(0.94)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .strokeBorder(
                                scheme == .light
                                    ? Color.black.opacity(0.08)
                                    : Color.white.opacity(0.12),
                                lineWidth: 0.8
                            )
                    }
                    .shadow(color: Color.black.opacity(0.10), radius: 7, y: 4)
            }

            ForEach(AppearanceTheme.allCases) { theme in
                ThemeMiniature(theme: theme, scheme: scheme)
                    .frame(maxWidth: .infinity)
                    .frame(height: 113)
                    .environment(\.colorScheme, scheme)
            }
        }
    }
}

private struct ThemeMiniature: View {
    let theme: AppearanceTheme
    let scheme: ColorScheme

    private var palette: JottedThemePalette { theme.palette }
    private var isDark: Bool { scheme == .dark }
    private var ambientColors: [Color] { theme.ambientColors(for: scheme) }
    private var closedAmbientColors: [Color] {
        guard let first = ambientColors.first else { return ambientColors }
        return ambientColors + [first]
    }

    var body: some View {
        ZStack {
            wallpaper

            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            panelTint.opacity(
                                theme.isChromatic
                                    ? (isDark ? 0.64 : 0.58)
                                    : (isDark ? 0.70 : 0.62)
                            )
                        )
                }
                .overlay {
                    if theme.isChromatic {
                        ThemeAmbientWash(
                            theme: theme,
                            colorScheme: scheme,
                            blurRadius: 13
                        )
                        .opacity(theme.boardAmbientOpacity(for: scheme) * 0.90)
                        .blendMode(isDark ? .screen : .normal)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    } else {
                        AngularGradient(
                            colors: closedAmbientColors,
                            center: .center,
                            startAngle: .degrees(-34),
                            endAngle: .degrees(326)
                        )
                        .opacity(isDark ? 0.084 : 0.066)
                        .blendMode(isDark ? .plusLighter : .softLight)
                        .blur(radius: 7)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                }
                .overlay(alignment: .topLeading) {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(
                                (isDark ? 0.13 : 0.72) * theme.decorativeHighlightMultiplier
                            ),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .overlay {
                    previewContent
                        .padding(9)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(isDark ? 0.17 : 0.78),
                            lineWidth: 0.8
                        )
                }
                .shadow(color: Color.black.opacity(isDark ? 0.24 : 0.13), radius: 9, y: 5)
                .padding(7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(Color.white.opacity(isDark ? 0.10 : 0.34), lineWidth: 0.7)
        }
    }

    private var wallpaper: some View {
        ZStack {
            LinearGradient(
                colors: wallpaperBaseColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(ambientColors[0].opacity(wallpaperGlowOpacities[0]))
                .frame(width: 82, height: 82)
                .blur(radius: 24)
                .offset(x: 52, y: -39)

            Circle()
                .fill(ambientColors[1].opacity(wallpaperGlowOpacities[1]))
                .frame(width: 68, height: 68)
                .blur(radius: 23)
                .offset(x: -57, y: 47)

            Circle()
                .fill(ambientColors.last?.opacity(wallpaperGlowOpacities[2]) ?? .clear)
                .frame(width: 62, height: 62)
                .blur(radius: 24)
                .offset(x: 50, y: 47)

            if ambientColors.count > 3 {
                Circle()
                    .fill(ambientColors[2].opacity(isDark ? 0.23 : 0.17))
                    .frame(width: 58, height: 58)
                    .blur(radius: 23)
                    .offset(x: -51, y: -42)
            }
        }
    }

    private var wallpaperBaseColors: [Color] {
        if theme == .abyss {
            return isDark
                ? [
                    Color(red: 0.020, green: 0.027, blue: 0.055),
                    Color(red: 0.090, green: 0.070, blue: 0.145)
                ]
                : [
                    Color(red: 0.965, green: 0.970, blue: 0.978),
                    Color(red: 0.820, green: 0.850, blue: 0.875)
                ]
        }

        return isDark
            ? [
                Color(red: 0.045, green: 0.051, blue: 0.063),
                Color(red: 0.125, green: 0.133, blue: 0.145)
            ]
            : [
                Color(red: 0.982, green: 0.984, blue: 0.988),
                Color(red: 0.875, green: 0.886, blue: 0.898)
            ]
    }

    private var wallpaperGlowOpacities: [Double] {
        switch (theme, isDark) {
        case (.graphite, true): [0.20, 0.14, 0.09]
        case (.graphite, false): [0.16, 0.11, 0.07]
        case (.aurora, true): [0.23, 0.20, 0.18]
        case (.aurora, false): [0.19, 0.16, 0.14]
        case (.blossom, true): [0.22, 0.18, 0.16]
        case (.blossom, false): [0.18, 0.15, 0.13]
        case (.amber, true): [0.20, 0.17, 0.14]
        case (.amber, false): [0.17, 0.14, 0.12]
        case (.abyss, true): [0.27, 0.23, 0.20]
        case (.abyss, false): [0.22, 0.18, 0.16]
        }
    }

    private var previewContent: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Capsule()
                    .fill(foreground.opacity(0.72))
                    .frame(width: 38, height: 4.5)

                Spacer()

                Circle()
                    .fill(filledAccent)
                    .frame(width: 16, height: 16)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.96))
                    }
            }

            previewRow(width: 43, emphasized: true)
            previewRow(width: 34, emphasized: false)
        }
    }

    private func previewRow(width: CGFloat, emphasized: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .strokeBorder(
                    emphasized ? accent : neutral.opacity(0.70),
                    lineWidth: 1.25
                )
                .frame(width: 13, height: 13)

            VStack(alignment: .leading, spacing: 3.5) {
                Capsule()
                    .fill(foreground.opacity(0.72))
                    .frame(width: width, height: 4)
                Capsule()
                    .fill(neutral.opacity(0.44))
                    .frame(width: width * 0.62, height: 3)
            }

            Spacer(minLength: 0)

            Circle()
                .fill(emphasized ? accent.opacity(0.18) : controlFill)
                .frame(width: 11, height: 11)
        }
        .padding(.horizontal, 7)
        .frame(height: 27)
        .background {
            RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                .fill(emphasized ? rowHover : rowFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                        .strokeBorder(rowBorder, lineWidth: 0.65)
                }
        }
    }

    private var accent: Color {
        isDark ? palette.accentDark : palette.accentLight
    }

    private var filledAccent: Color {
        isDark ? palette.filledAccentDark : palette.filledAccentLight
    }

    private var panelTint: Color {
        isDark ? palette.panelTintDark : palette.panelTintLight
    }

    private var controlFill: Color {
        isDark ? palette.controlFillDark : palette.controlFillLight
    }

    private var foreground: Color {
        isDark ? palette.controlForegroundDark : palette.controlForegroundLight
    }

    private var rowFill: Color {
        isDark ? palette.rowFillDark : palette.rowFillLight
    }

    private var rowHover: Color {
        isDark ? palette.rowHoverDark : palette.rowHoverLight
    }

    private var rowBorder: Color {
        isDark ? palette.rowBorderDark : palette.rowBorderLight
    }

    private var neutral: Color {
        isDark ? palette.neutralDark : palette.neutralLight
    }
}
