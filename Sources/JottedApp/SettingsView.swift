import SwiftUI

enum GlassTransparencyPreference {
    static let key = "JottedGlassTransparency"
    static let legacyKey = "JottedGlassTransparencyLevel"
    static let appearanceVersionKey = "JottedGlassAppearanceVersion"
    static let defaultValue = 0.50
    private static let currentAppearanceVersion = 3
    private static let previousDefaultValue = 0.30

    static func migrateIfNeeded(defaults: UserDefaults = .standard) {
        if defaults.object(forKey: key) == nil {
            let value: Double
            if defaults.object(forKey: legacyKey) != nil {
                switch defaults.integer(forKey: legacyKey) {
                case 2: value = 0.0
                default: value = defaultValue
                }
            } else {
                value = defaultValue
            }
            defaults.set(value, forKey: key)
        } else if defaults.integer(forKey: appearanceVersionKey) < currentAppearanceVersion {
            let existingValue = defaults.double(forKey: key)
            if abs(existingValue - previousDefaultValue) < 0.001 {
                defaults.set(defaultValue, forKey: key)
            }
        }
        defaults.set(currentAppearanceVersion, forKey: appearanceVersionKey)
    }

    /// Multiplier applied to decorative overlays so highlights thin out along
    /// with the glass instead of staying put and looking pasted on.
    static func extraFade(value: Double) -> Double {
        let transparency = min(max(value, 0), 1)
        return 1 - (0.55 * transparency)
    }

    /// Strength of the halo drawn behind text.
    ///
    /// Past roughly half transparency there is not enough glass left to
    /// guarantee contrast, and no choice of palette can fix that — the panel
    /// is showing an arbitrary wallpaper. A halo in the opposite luminance to
    /// the text separates the glyphs from whatever is behind them regardless
    /// of its hue, which is how the system keeps desktop icon labels readable.
    static func legibilityHaloOpacity(value: Double) -> Double {
        legibilityFactor(value: value) * 0.95
    }

    /// Normalised 0…1 ramp describing how much help the text needs. Zero while
    /// the glass is still thick enough to carry contrast on its own.
    static func legibilityFactor(value: Double) -> Double {
        let transparency = min(max(value, 0), 1)
        let threshold = 0.35
        guard transparency > threshold else { return 0 }
        return (transparency - threshold) / (1 - threshold)
    }

    /// Opacity of the board's vibrancy material.
    ///
    /// The old curve only travelled from 0.94 down to 0.76 before a second
    /// multiplier was applied, so dragging the slider barely changed anything
    /// — 100% still left a nearly solid panel. The range now spans almost the
    /// full scale: opaque at 0, genuinely see-through at 1.
    static func materialAlpha(value: Double, for scheme: ColorScheme) -> CGFloat {
        let transparency = min(max(value, 0), 1)
        let baseAlpha: Double
        switch scheme {
        case .light:
            baseAlpha = 0.96 - (0.82 * transparency)
        case .dark:
            baseAlpha = 0.97 - (0.79 * transparency)
        @unknown default:
            baseAlpha = 0.96 - (0.82 * transparency)
        }
        return CGFloat(baseAlpha)
    }
}

struct JottedSettingsView: View {
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    @ObservedObject private var localization = AppLocalization.shared

    let onClose: () -> Void

    @AppStorage(GlassTransparencyPreference.key)
    private var transparency = GlassTransparencyPreference.defaultValue
    @AppStorage(AppearanceThemePreference.key)
    private var themeRawValue = AppearanceThemePreference.defaultValue

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private let controlRailWidth: CGFloat = 192

    init(
        launchAtLoginManager: LaunchAtLoginManager,
        onClose: @escaping () -> Void = {}
    ) {
        self.launchAtLoginManager = launchAtLoginManager
        self.onClose = onClose
    }

    private var selectedTheme: AppearanceTheme {
        AppearanceTheme(rawValue: themeRawValue) ?? .defaultTheme
    }

    private var settingsAccent: Color {
        JottedPalette.accent(for: colorScheme)
    }

    private var percentageBadgeFill: Color {
        JottedPalette.filledAccent(for: colorScheme)
    }

    private var launchIssueText: String? {
        if launchAtLoginManager.needsApproval {
            return localization.text(.launchAtLoginRequiresApproval)
        }
        if launchAtLoginManager.message != nil {
            return localization.text(.launchAtLoginFailed)
        }
        return nil
    }

    private var launchIssueColor: Color {
        if launchAtLoginManager.needsApproval {
            return JottedPalette.warning(for: colorScheme)
        }
        return JottedPalette.danger(for: colorScheme)
    }

    var body: some View {
        // This preference read makes every palette-backed surface update in
        // the same render pass as the selected theme.
        let _ = themeRawValue

        VStack(spacing: 0) {
            panelHeader

            Spacer()
                .frame(height: 8)

            appearanceCard

            Spacer()
                .frame(height: 8)

            generalCard
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(
            width: JottedLayout.settingsPanelSize.width,
            height: JottedLayout.settingsPanelSize.height,
            alignment: .topLeading
        )
        .background {
            ZStack {
                // Both glass paths render sheer over a transparent panel, so
                // the window keeps an opaque-enough backing of its own.
                JottedPalette.panelTint(for: colorScheme)
                    .opacity(colorScheme == .dark ? 0.58 : 0.62)
                ThemeAmbientWash(theme: selectedTheme, colorScheme: colorScheme)
                    .opacity(selectedTheme.floatingAmbientOpacity(for: colorScheme))
                    .blendMode(colorScheme == .dark ? .screen : .normal)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .jottedGlass(
            in: RoundedRectangle(cornerRadius: 26, style: .continuous),
            tint: selectedTheme.glassTint(for: colorScheme)
        ) {
            LegacyGlassSurface(
                shape: RoundedRectangle(cornerRadius: 26, style: .continuous),
                tint: JottedPalette.panelTint(for: colorScheme)
                    .opacity(colorScheme == .dark ? 0.42 : 0.46)
            )
        }
        .shadow(
            color: colorScheme == .dark
                ? Color.black.opacity(0.30)
                : selectedTheme.isChromatic
                    ? Color.black.opacity(0.075)
                    : JottedPalette.filledAccent(for: colorScheme).opacity(0.105),
            radius: colorScheme == .dark ? 24 : 26,
            y: colorScheme == .dark ? 11 : 10
        )
        .animation(.easeInOut(duration: 0.18), value: themeRawValue)
        .onAppear {
            launchAtLoginManager.refresh()
        }
        .onExitCommand(perform: onClose)
        .environment(\.locale, localization.locale)
    }

    private var panelHeader: some View {
        HStack(spacing: 10) {
            // The whole title strip is the drag handle. Background dragging is
            // off window-wide so it cannot hijack the transparency slider, so
            // this is the only way to move the panel — it needs to be the full
            // width of the header, not just the gap next to the title.
            HStack(spacing: 0) {
                Text(settingsTitle)
                    .font(.system(size: 16, weight: .semibold))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay { WindowDragArea() }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(JottedPalette.controlForeground(for: colorScheme).opacity(0.82))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(JottedPalette.controlFill(for: colorScheme))
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        Color.white.opacity(colorScheme == .dark ? 0.12 : 0.84),
                                        lineWidth: 0.7
                                    )
                            }
                    )
                    .shadow(
                        color: JottedPalette.filledAccent(for: colorScheme)
                            .opacity(colorScheme == .dark ? 0.12 : 0.06),
                        radius: 5,
                        y: 2
                    )
            }
            .buttonStyle(.plain)
            .help(localization.text(.cancel))
            .accessibilityLabel(localization.text(.cancel))
        }
        .frame(height: 26)
    }

    private var settingsTitle: String {
        localization.text(.settings)
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: "...", with: "")
    }

    private var appearanceCard: some View {
        VStack(spacing: 0) {
            themeRow
            cardDivider
            transparencyRow
        }
        .frame(maxWidth: .infinity)
        .frame(height: 113)
        .background(cardSurface)
    }

    private var generalCard: some View {
        VStack(spacing: 0) {
            languageRow
            cardDivider
            launchAtLoginRow
        }
        .frame(maxWidth: .infinity)
        .frame(height: 113)
        .background(cardSurface)
    }

    private var themeRow: some View {
        HStack(spacing: 8) {
            rowTitle(localization.text(.theme))
                .layoutPriority(1)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(AppearanceTheme.allCases) { theme in
                    themeButton(theme)
                }
            }
            .frame(width: controlRailWidth)
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
    }

    private var transparencyRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                rowTitle(localization.text(.panelTransparency))

                if reduceTransparency {
                    Image(systemName: "accessibility")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .help(localization.text(.reduceTransparencyNotice))
                        .accessibilityLabel(localization.text(.reduceTransparencyNotice))
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            InlinePercentageSlider(
                value: $transparency,
                accent: settingsAccent,
                badgeFill: percentageBadgeFill,
                isDisabled: reduceTransparency,
                accessibilityLabel: localization.text(.glassTransparencyAccessibility),
                width: controlRailWidth
            )
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
    }

    private var languageRow: some View {
        HStack(spacing: 8) {
            rowTitle(localization.text(.language))
                .layoutPriority(1)

            Spacer(minLength: 0)

            Menu {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        localization.setLanguage(language)
                    } label: {
                        if localization.selectedLanguage == language {
                            Label(localization.languageOptionName(language), systemImage: "checkmark")
                        } else {
                            Text(localization.languageOptionName(language))
                        }
                    }
                }
            } label: {
                Text(localization.languageOptionName(localization.selectedLanguage))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .foregroundStyle(JottedPalette.controlForeground(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .menuStyle(.borderlessButton)
            .frame(width: controlRailWidth, height: 30, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
    }

    private var launchAtLoginRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                rowTitle(localization.text(.launchAtLogin))

                if let launchIssueText {
                    Image(
                        systemName: launchAtLoginManager.needsApproval
                            ? "exclamationmark.circle"
                            : "exclamationmark.triangle"
                    )
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(launchIssueColor)
                    .help(launchIssueText)
                    .accessibilityLabel(launchIssueText)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if launchAtLoginManager.needsApproval {
                    Button {
                        launchAtLoginManager.openSystemLoginItemsSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(settingsAccent.opacity(colorScheme == .dark ? 0.15 : 0.07))
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(settingsAccent)
                    .help(localization.text(.openSystemSettings))
                    .accessibilityLabel(localization.text(.openSystemSettings))
                }

                Toggle(
                    "",
                    isOn: Binding(
                        get: { launchAtLoginManager.enabled },
                        set: { launchAtLoginManager.setEnabled($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.regular)
                .tint(settingsAccent)
                .fixedSize()
                .accessibilityLabel(localization.text(.launchAtLogin))
                .accessibilityValue(
                    localization.text(
                        launchAtLoginManager.enabled
                            ? .launchAtLoginEnabled
                            : .launchAtLoginDisabled
                    )
                )
            }
            .frame(width: controlRailWidth, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
    }

    private func rowTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13.5, weight: .semibold))
            .lineLimit(2)
            .minimumScaleFactor(0.78)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
            .padding(.horizontal, 12)
    }

    /// A neutral grouped-settings card. No theme tint, no gradient sheen —
    /// the accent belongs on the controls inside it.
    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.045))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.06),
                        lineWidth: 0.8
                    )
            }
    }

    private func themeButton(_ theme: AppearanceTheme) -> some View {
        let isSelected = selectedTheme == theme
        let name = themeName(theme)

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                themeRawValue = theme.rawValue
            }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(
                        isSelected
                            ? settingsAccent.opacity(0.76)
                            : Color.clear,
                        lineWidth: 1.6
                    )
                    .frame(width: 30, height: 30)

                // A solid swatch of the accent, the way a list colour is shown
                // in the system's own reminder lists.
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.accent(for: colorScheme),
                                theme.companion(for: colorScheme)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 32, height: 32)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(name)
        .accessibilityValue(isSelected ? localization.text(.selected) : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func themeName(_ theme: AppearanceTheme) -> String {
        localization.text(theme.localizationKey)
    }
}

struct JottedSettingsWindowRoot: View {
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.clear
            JottedSettingsView(
                launchAtLoginManager: launchAtLoginManager,
                onClose: onClose
            )
        }
        .frame(
            width: JottedLayout.settingsWindowSize.width,
            height: JottedLayout.settingsWindowSize.height
        )
        .background(Color.clear)
    }
}

/// The transparency control.
///
/// This used to draw its own track and thumb and then lay a real `Slider` on
/// top at `opacity(0.001)` to pick up the drag. The settings window had
/// `isMovableByWindowBackground` set, and AppKit hands a drag to the window
/// whenever the view beneath the cursor does not claim it — which a
/// near-invisible control does not reliably do. Dragging the slider moved the
/// window and the value never changed.
///
/// The window is no longer movable by its background (its header carries an
/// explicit drag surface instead), and the invisible `Slider` is replaced by a
/// real gesture on the visible track.
private struct InlinePercentageSlider: View {
    @Binding var value: Double

    let accent: Color
    let badgeFill: Color
    let isDisabled: Bool
    let accessibilityLabel: String
    let width: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private let trackHeight: CGFloat = 6
    private let thumbDiameter: CGFloat = 18

    private var normalizedValue: Double {
        min(max(value, 0), 1)
    }

    private var percentage: Int {
        Int((normalizedValue * 100).rounded())
    }

    private func transparency(atX x: CGFloat, width: CGFloat) -> Double {
        let inset = thumbDiameter / 2
        let travel = max(width - thumbDiameter, 1)
        return min(max(Double((x - inset) / travel), 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let inset = thumbDiameter / 2
            let travel = max(geometry.size.width - thumbDiameter, 1)
            let thumbCenter = inset + CGFloat(normalizedValue) * travel
            let badgeHalfWidth: CGFloat = 21
            let badgeCenter = min(
                max(thumbCenter, badgeHalfWidth),
                geometry.size.width - badgeHalfWidth
            )

            ZStack(alignment: .topLeading) {
                Text("\(percentage)%")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(width: 42, height: 21)
                    .background(Capsule(style: .continuous).fill(badgeFill))
                    .position(x: badgeCenter, y: 11)

                Capsule(style: .continuous)
                    .fill(JottedPalette.controlForeground(for: colorScheme).opacity(0.14))
                    .frame(width: geometry.size.width, height: trackHeight)
                    .position(x: geometry.size.width / 2, y: 32)

                Capsule(style: .continuous)
                    .fill(accent)
                    .frame(width: max(thumbCenter, trackHeight), height: trackHeight)
                    .position(x: max(thumbCenter, trackHeight) / 2, y: 32)

                Circle()
                    .fill(Color.white)
                    .overlay {
                        Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 0.7)
                    }
                    .shadow(color: Color.black.opacity(0.16), radius: 2.5, y: 1)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .position(x: thumbCenter, y: 32)

                // Generous hit area covering track and thumb.
                Color.clear
                    .frame(width: geometry.size.width, height: 30)
                    .contentShape(Rectangle())
                    .position(x: geometry.size.width / 2, y: 32)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                guard !isDisabled else { return }
                                value = transparency(
                                    atX: drag.location.x,
                                    width: geometry.size.width
                                )
                            }
                    )
            }
        }
        .frame(width: width, height: 44)
        .opacity(isDisabled ? 0.52 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(percentage)%")
        .accessibilityAdjustableAction { direction in
            guard !isDisabled else { return }
            switch direction {
            case .increment: value = min(normalizedValue + 0.05, 1)
            case .decrement: value = max(normalizedValue - 0.05, 0)
            @unknown default: break
            }
        }
    }
}
