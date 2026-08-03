import Combine
import JottedCore
import SwiftUI

private enum BoardSectionKind: Identifiable {
    case overdue
    case today
    case upcoming
    case undated

    var id: Self { self }

    var localizationKey: L10n.Key {
        switch self {
        case .overdue: .sectionOverdue
        case .today: .sectionToday
        case .upcoming: .sectionUpcoming
        case .undated: .sectionUndated
        }
    }
}

private struct BoardSection: Identifiable {
    let kind: BoardSectionKind
    let items: [TodoItem]
    var id: BoardSectionKind { kind }
}

private struct UndoPayload: Identifiable {
    enum Action {
        case restored
        case completed
        case deleted

        @MainActor
        func message(for title: String, localization: AppLocalization) -> String {
            switch self {
            case .restored: localization.text(.restoredTask(title))
            case .completed: localization.text(.completedTask(title))
            case .deleted: localization.text(.deletedTask(title))
            }
        }
    }

    let id = UUID()
    let item: TodoItem
    let action: Action
}

/// App-level commands, repeated wherever a context menu can appear.
///
/// The board menu used to be the only route to Quit, and it only opened on
/// empty board space — so a board full of rows had no reachable exit. These
/// items are now attached to every context menu in the app.
struct BoardCommandMenuItems: View {
    @ObservedObject private var localization = AppLocalization.shared
    @AppStorage("JottedIsPinned") private var isPinned = false

    var body: some View {
        Button(localization.text(.addItem), systemImage: "plus") {
            NotificationCenter.default.post(name: .jottedCreateTask, object: nil)
        }
        Button(
            localization.text(isPinned ? .stopKeepingOnTop : .keepOnTop),
            systemImage: "pin"
        ) {
            NotificationCenter.default.post(name: .jottedTogglePin, object: nil)
        }
        Button(localization.text(.settings), systemImage: "gearshape") {
            NotificationCenter.default.post(name: .jottedShowSettings, object: nil)
        }
        Button(localization.text(.hideApp), systemImage: "eye.slash") {
            NotificationCenter.default.post(name: .jottedHideBoard, object: nil)
        }
        Divider()
        Button(localization.text(.quitApp), systemImage: "power") {
            NSApp.terminate(nil)
        }
    }
}

struct BoardView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var windowCoordinator: WindowCoordinator
    @ObservedObject private var localization = AppLocalization.shared
    var snapshotMode = false
    let onPresentEditor: (TaskEditorContext) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var now = Date()
    @State private var showsCompleted = false
    @State private var undoPayload: UndoPayload?
    @State private var undoDismissTask: Task<Void, Never>?
    @AppStorage(GlassTransparencyPreference.key)
    private var glassTransparency = GlassTransparencyPreference.defaultValue
    @AppStorage(AppearanceThemePreference.key)
    private var appearanceTheme = AppearanceThemePreference.defaultValue

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.clear

            boardCard
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.34)
                        : Color.black.opacity(0.14),
                    radius: 12,
                    y: 5
                )
                .padding(JottedLayout.windowInset)
        }
        .background(Color.clear)
        .onReceive(minuteTimer) { value in
            now = value
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            now = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .jottedCreateTask)) { _ in
            openCreateEditor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .jottedTogglePin)) { _ in
            windowCoordinator.togglePinned()
        }
        .onReceive(NotificationCenter.default.publisher(for: .jottedHideBoard)) { _ in
            windowCoordinator.hide()
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: undoPayload?.id)
    }

    private var boardCard: some View {
        ZStack {
            panelBackground

            mainContent(isCondensed: windowCoordinator.presentationMode == .condensed)

            if let undoPayload {
                VStack {
                    Spacer()
                    undoToast(undoPayload)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: JottedLayout.boardCornerRadius, style: .continuous))
        .overlay {
            // A single hairline instead of the old white specular sheet. That
            // sheet was a large part of why the panel looked milky and opaque.
            RoundedRectangle(cornerRadius: JottedLayout.boardCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.22 : 0.55),
                            activeAppearanceTheme.accent(for: colorScheme)
                                .opacity(boardBorderAccentOpacity)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .contextMenu {
            BoardCommandMenuItems()
        }
    }

    private var panelBackground: some View {
        ZStack {
            if reduceTransparency {
                JottedPalette.panelTint(for: colorScheme)
            } else if snapshotMode {
                JottedPalette.panelTint(for: colorScheme)
                    .opacity(snapshotCompositeOpacity)
            } else {
                // Neutral glass. The theme is expressed by the accent on the
                // controls and by the glow below, never by tinting the whole
                // surface — that is what was blocking the desktop.
                VisualEffectView(
                    material: .underWindowBackground,
                    blendingMode: .behindWindow,
                    alpha: effectiveMaterialAlpha
                )

                JottedPalette.panelTint(for: colorScheme)
                    .opacity(effectivePanelTintOpacity)
            }

            ThemeAmbientWash(
                theme: activeAppearanceTheme,
                colorScheme: colorScheme,
                reach: 0.30
            )
            .opacity(glowOpacity)
        }
        .ignoresSafeArea()
    }

    private var glowOpacity: Double {
        let base = activeAppearanceTheme.topGlowOpacity(for: colorScheme)
        if reduceTransparency || snapshotMode {
            return base
        }
        // The glow rides on the glass, so it thins out as the glass does —
        // but never all the way to zero, or the theme would vanish at high
        // transparency the way it used to.
        return base * (0.55 + 0.45 * highTransparencyFade)
    }

    private var activeAppearanceTheme: AppearanceTheme {
        AppearanceTheme(rawValue: appearanceTheme) ?? .defaultTheme
    }

    @ViewBuilder
    private func mainContent(isCondensed: Bool) -> some View {
        if store.pendingItems.isEmpty && store.completedItems.isEmpty {
            emptyState(isCondensed: isCondensed)
        } else {
            taskList(isCondensed: isCondensed)
        }
    }

    private func taskList(isCondensed: Bool) -> some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(spacing: 0) {
                    LazyVStack(spacing: isCondensed ? 10 : 14) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: isCondensed ? 2 : 3) {
                                sectionHeader(
                                    localization.text(section.kind.localizationKey),
                                    count: section.items.count
                                )
                                ForEach(section.items) { item in
                                    taskRow(
                                        item,
                                        isCondensed: isCondensed,
                                        isOverdue: section.kind == .overdue
                                    )
                                }
                            }
                        }

                        // Flattened into the LazyVStack on purpose. When the
                        // completed rows lived inside a nested VStack the lazy
                        // stack saw them as one child and built every row up
                        // front; as direct children they are only realized as
                        // they scroll into view.
                        if !store.completedItems.isEmpty {
                            completedHeader(isCondensed: isCondensed)

                            if showsCompleted {
                                ForEach(store.completedItems) { item in
                                    taskRow(item, isCondensed: isCondensed, isOverdue: false)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, isCondensed ? 8 : 10)
                    .padding(.top, isCondensed ? 14 : 20)

                    // This invisible surface occupies any unused board space,
                    // so removing the header does not remove window dragging.
                    WindowDragArea()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(minHeight: isCondensed ? 12 : 18)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: viewport.size.height, alignment: .top)
            }
            .scrollIndicators(.never)
        }
    }

    private func completedHeader(isCondensed: Bool) -> some View {
        HStack(spacing: 6) {
            Button {
                toggleCompletedSection()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(showsCompleted ? 90 : 0))
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.16),
                            value: showsCompleted
                        )
                    Text(localization.text(.sectionCompleted))
                    Text("\(store.completedItems.count)")
                        .monospacedDigit()
                        .opacity(0.65)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(sectionHeaderColor)
                .legibilityHalo(halo)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(localization.text(.sectionCompleted))

            Spacer()
                .overlay {
                    WindowDragArea()
                }

            if showsCompleted {
                Button(localization.text(.clear)) {
                    store.clearCompleted()
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(sectionHeaderColor)
                .legibilityHalo(halo)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, isCondensed ? 2 : 4)
        .padding(.bottom, 2)
        .contextMenu {
                Button(
                    localization.text(.sectionCompleted),
                    systemImage: showsCompleted ? "chevron.down" : "chevron.right"
                ) {
                    toggleCompletedSection()
                }
                Divider()
                BoardCommandMenuItems()
            }
    }

    /// Deliberately not wrapped in `withAnimation`. Animating the insertion of
    /// an arbitrarily long list forced SwiftUI to lay out and composite every
    /// completed row inside a single frame, which is what froze the board on
    /// expand — and, while frozen, swallowed the click that would collapse it
    /// again.
    private func toggleCompletedSection() {
        showsCompleted.toggle()
    }

    private func emptyState(isCondensed: Bool) -> some View {
        Text(localization.text(.blankBoardHint))
            .font(.system(size: isCondensed ? 11 : 12, weight: .medium))
            .foregroundStyle(.secondary.opacity(0.72))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                WindowDragArea()
            }
    }

    private var sections: [BoardSection] {
        let pending = store.pendingItems
        let calendar = Calendar.autoupdatingCurrent

        var overdue: [TodoItem] = []
        var today: [TodoItem] = []
        var upcoming: [TodoItem] = []
        var undated: [TodoItem] = []

        // Single pass. The previous implementation ran four separate filters
        // over the pending list, each of which re-evaluated the deadline math.
        for item in pending {
            guard let deadline = item.deadline else {
                undated.append(item)
                continue
            }
            if item.deadlineIsOverdue(at: now, calendar: calendar) {
                overdue.append(item)
            } else if calendar.isDate(deadline, inSameDayAs: now) {
                today.append(item)
            } else {
                upcoming.append(item)
            }
        }

        return [
            BoardSection(kind: .overdue, items: overdue),
            BoardSection(kind: .today, items: today),
            BoardSection(kind: .upcoming, items: upcoming),
            BoardSection(kind: .undated, items: undated)
        ].filter { !$0.items.isEmpty }
    }

    private var halo: Color {
        JottedPalette.legibilityHalo(
            for: colorScheme,
            transparency: normalizedGlassTransparency,
            reduceTransparency: reduceTransparency
        )
    }

    private var legibility: Double {
        reduceTransparency
            ? 0
            : GlassTransparencyPreference.legibilityFactor(value: normalizedGlassTransparency)
    }

    /// Section headings carry the theme, the way a list colour does in the
    /// system's own reminder lists — but they give ground to legibility as the
    /// glass thins, since a mid-tone heading on a bright wallpaper is the
    /// first thing to disappear.
    private var sectionHeaderColor: Color {
        let base = activeAppearanceTheme.isChromatic
            ? activeAppearanceTheme.accent(for: colorScheme).opacity(0.9)
            : JottedPalette.controlForeground(for: colorScheme).opacity(0.5)
        return JottedPalette.legible(base, for: colorScheme, legibility: legibility)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 5) {
            Text(title)
            Text("\(count)")
                .monospacedDigit()
                .opacity(0.6)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(sectionHeaderColor)
        .legibilityHalo(halo)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.bottom, 2)
        .overlay {
            WindowDragArea()
        }
    }

    private func taskRow(_ item: TodoItem, isCondensed: Bool, isOverdue: Bool) -> some View {
        TaskRowView(
            item: item,
            now: now,
            theme: activeAppearanceTheme,
            isCondensed: isCondensed,
            isOverdue: isOverdue,
            onToggle: {
                let previous = item
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86)) {
                    store.toggleCompletion(item)
                }
                showUndo(for: previous, action: item.isCompleted ? .restored : .completed)
            },
            onEdit: {
                openEditEditor(item)
            },
            onDelete: {
                store.delete(item)
                showUndo(for: item, action: .deleted)
            }
        )
    }

    private func openCreateEditor() {
        onPresentEditor(.create)
    }

    private func openEditEditor(_ item: TodoItem) {
        onPresentEditor(TaskEditorContext(mode: .edit(item)))
    }

    private func showUndo(for item: TodoItem, action: UndoPayload.Action) {
        undoDismissTask?.cancel()
        let payload = UndoPayload(item: item, action: action)
        undoPayload = payload
        undoDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled, undoPayload?.id == payload.id else { return }
            undoPayload = nil
        }
    }

    private func undoToast(_ payload: UndoPayload) -> some View {
        HStack(spacing: 10) {
            Text(payload.action.message(for: payload.item.title, localization: localization))
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 4)
            Button(localization.text(.undo)) {
                undoDismissTask?.cancel()
                store.restore(payload.item)
                undoPayload = nil
            }
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(JottedPalette.accent(for: colorScheme))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .jottedGlass(
            in: Capsule(style: .continuous),
            tint: activeAppearanceTheme.glassTint(for: colorScheme)
        ) {
            LegacyGlassSurface(
                shape: Capsule(style: .continuous),
                tint: JottedPalette.panelTint(for: colorScheme)
                    .opacity(colorScheme == .dark ? 0.78 : 0.72),
                material: .menu
            )
        }
        .shadow(
            color: colorScheme == .dark
                ? .black.opacity(0.26)
                : JottedPalette.filledAccent.opacity(0.10),
            radius: 14,
            y: 6
        )
    }

    private var normalizedGlassTransparency: Double {
        min(max(glassTransparency, 0), 1)
    }

    private var highTransparencyFade: Double {
        GlassTransparencyPreference.extraFade(value: normalizedGlassTransparency)
    }

    private var boardBorderAccentOpacity: Double {
        activeAppearanceTheme.hairlineOpacity(for: colorScheme)
    }

    private var effectiveMaterialAlpha: CGFloat {
        GlassTransparencyPreference.materialAlpha(
            value: normalizedGlassTransparency,
            for: colorScheme
        )
    }

    /// Solid tint layered over the vibrancy material. Falls away almost
    /// entirely at full transparency so the material is the only thing left
    /// between the board and the desktop.
    private var effectivePanelTintOpacity: Double {
        colorScheme == .dark
            ? 0.55 - (0.53 * normalizedGlassTransparency)
            : 0.50 - (0.48 * normalizedGlassTransparency)
    }

    /// Snapshot rendering has no desktop behind the window, so reproduce the
    /// combined opacity of the live material and tint while retaining alpha in
    /// the exported PNG. This makes the README capture respond to the same
    /// transparency preference without depending on the capture machine's
    /// wallpaper.
    private var snapshotCompositeOpacity: Double {
        let materialOpacity = Double(effectiveMaterialAlpha)
        return 1 - ((1 - materialOpacity) * (1 - effectivePanelTintOpacity))
    }
}
