import Foundation
import JottedCore
import SwiftUI

struct TaskRowView: View {
    let item: TodoItem
    let now: Date
    /// Carried explicitly so a theme switch invalidates every row. The palette
    /// itself is read from `JottedPalette`, which is not observable.
    let theme: AppearanceTheme
    var isCondensed = false
    var isOverdue = false
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @ObservedObject private var localization = AppLocalization.shared
    @AppStorage(GlassTransparencyPreference.key)
    private var glassTransparency = GlassTransparencyPreference.defaultValue
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var halo: Color {
        JottedPalette.legibilityHalo(
            for: colorScheme,
            transparency: glassTransparency,
            reduceTransparency: reduceTransparency
        )
    }

    private var legibility: Double {
        reduceTransparency
            ? 0
            : GlassTransparencyPreference.legibilityFactor(value: glassTransparency)
    }

    private var deadlinePresentation: DeadlinePresentation? {
        item.deadline.map {
            DeadlinePresentation.make(
                for: $0,
                isAllDay: item.isAllDay,
                now: now,
                language: localization.resolvedLanguage,
                locale: localization.locale
            )
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: isCondensed ? 8 : 10) {
            completionToggle

            VStack(alignment: .leading, spacing: isCondensed ? 1 : 3) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(.system(size: isCondensed ? 12.5 : 13.5, weight: .medium))
                        .foregroundStyle(.primary.opacity(item.isCompleted ? 0.42 : 1))
                        .strikethrough(item.isCompleted, color: .secondary.opacity(0.6))
                        .lineLimit(item.deadline == nil ? 1 : (isCondensed ? 1 : 2))
                        .multilineTextAlignment(.leading)

                    if !item.isCompleted, item.priority != .low {
                        priorityMark
                    }
                }

                if let deadlinePresentation {
                    HStack(spacing: 4) {
                        Label(deadlinePresentation.text, systemImage: deadlinePresentation.symbol)
                            .lineLimit(1)
                            // Was 0.80, which let a narrow board shrink this
                            // line to roughly 8pt — below the size where CJK
                            // glyphs hold their strokes on a busy backdrop.
                            .minimumScaleFactor(0.92)
                            .layoutPriority(1)

                        if !item.isCompleted, let countdownText = deadlinePresentation.countdownText {
                            Text("· \(countdownText)")
                                .opacity(0.9)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    // Deadlines carry real information and sit on whatever the
                    // desktop shows through, so they get a size and weight that
                    // survive it rather than the smallest legible caption.
                    .font(.system(size: isCondensed ? 10.5 : 11.5, weight: .semibold))
                    .foregroundStyle(
                        JottedPalette.legible(
                            deadlinePresentation.tone.color(for: colorScheme),
                            for: colorScheme,
                            legibility: legibility
                        )
                        .opacity(item.isCompleted ? 0.40 : 1)
                    )
                    .monospacedDigit()
                    .lineLimit(1)
                    .accessibilityHidden(true)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .legibilityHalo(halo)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            overflowMenu
        }
        .padding(.leading, isCondensed ? 8 : 10)
        .padding(.trailing, isCondensed ? 4 : 6)
        .padding(
            .vertical,
            item.deadline == nil
                ? (isCondensed ? 2 : 3)
                : (isCondensed ? 3 : 5)
        )
        .frame(
            minHeight: item.deadline == nil
                ? (isCondensed ? 34 : 38)
                : (isCondensed ? 42 : 48)
        )
        // A single flat fill. No per-row material, blur, gradient stack or
        // shadow: those forced one offscreen pass per row and were the reason
        // a long completed list stuttered on expand.
        .background {
            RoundedRectangle(cornerRadius: JottedLayout.rowCornerRadius, style: .continuous)
                .fill(
                    isHovering
                        ? JottedPalette.rowFill(for: colorScheme, hovering: true)
                        : Color.clear
                )
        }
        .overlay(alignment: .leading) {
            if isOverdue, !item.isCompleted {
                Capsule(style: .continuous)
                    .fill(JottedPalette.danger(for: colorScheme))
                    .frame(width: 2.5)
                    .padding(.vertical, isCondensed ? 7 : 9)
                    .padding(.leading, 2)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: JottedLayout.rowCornerRadius, style: .continuous))
        .contextMenu {
            Button(localization.text(.edit), systemImage: "pencil", action: onEdit)
            Button(
                localization.text(item.isCompleted ? .markIncomplete : .markComplete),
                systemImage: "checkmark.circle",
                action: onToggle
            )
            Divider()
            Button(localization.text(.delete), systemImage: "trash", role: .destructive, action: onDelete)
            Divider()
            // The board menu lives on empty space, and a full board leaves no
            // empty space to right-click. Repeating the app-level actions here
            // keeps Quit reachable no matter how many rows are on screen.
            BoardCommandMenuItems()
        }
        .onHover { hovering in
            if reduceMotion {
                isHovering = hovering
            } else {
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    /// An unchecked ring is a hairline circle, which is the thinnest thing on
    /// the board and so the first to disappear into a busy desktop. It gets
    /// the same treatment as the text — deepened colour, and a heavier stroke
    /// as the glass thins — plus a floor on its opacity, since the old
    /// `Color.secondary.opacity(0.42)` composited almost to nothing once the
    /// panel stopped backing it.
    private var ringColor: Color {
        // At rest the ring is the theme colour with most of its saturation
        // taken out — a tinted grey that still belongs to the theme, rather
        // than the same neutral grey in all five.
        let base = item.isCompleted || isHovering
            ? theme.accent(for: colorScheme)
            : JottedPalette
                .quieted(theme.accent(for: colorScheme), by: 0.55)
                .opacity(0.72 + 0.28 * legibility)
        return JottedPalette.legible(base, for: colorScheme, legibility: legibility)
    }

    private var ringWeight: Font.Weight {
        legibility > 0.4 ? .semibold : .medium
    }

    private var completionToggle: some View {
        Button(action: onToggle) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: isCondensed ? 15 : 16.5, weight: ringWeight))
                // The filled ring uses the theme accent, matching how a list
                // colour marks completion in the system's reminder lists.
                .foregroundStyle(ringColor)
                .contentTransition(.symbolEffect(.replace))
                .legibilityHalo(halo)
                .frame(width: isCondensed ? 22 : 24, height: isCondensed ? 26 : 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(localization.text(item.isCompleted ? .markIncomplete : .markComplete))
        .accessibilityLabel(localization.text(item.isCompleted ? .markIncomplete : .markComplete))
    }

    private var overflowMenu: some View {
        Menu {
            Button(localization.text(.edit), systemImage: "pencil", action: onEdit)
            Button(
                localization.text(item.isCompleted ? .markIncomplete : .markComplete),
                systemImage: "checkmark.circle",
                action: onToggle
            )
            Divider()
            Button(localization.text(.delete), systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: isCondensed ? 24 : 26, height: isCondensed ? 26 : 28)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .opacity(isHovering ? 1 : 0)
        .accessibilityLabel(localization.text(.moreActions))
    }

    /// Reminders-style urgency marks. Replaces the old single-letter chips,
    /// which read as cramped and untranslatable at small sizes.
    private var priorityMark: some View {
        let isHigh = item.priority == .high
        return Text(isHigh ? "!!" : "!")
            .font(.system(size: isCondensed ? 11 : 12, weight: .bold))
            .foregroundStyle(
                isHigh
                    ? JottedPalette.danger(for: colorScheme)
                    : JottedPalette.warning(for: colorScheme)
            )
            .accessibilityLabel(
                localization.text(isHigh ? .highPriorityAccessibility : .mediumPriorityAccessibility)
            )
    }

    private var accessibilityDescription: String {
        var parts = [
            item.title,
            localization.text(item.isCompleted ? .completedState : .incompleteState)
        ]
        if let deadlinePresentation {
            parts.append(deadlinePresentation.accessibilityText)
            if !item.isCompleted, let countdownText = deadlinePresentation.countdownText {
                parts.append(countdownText)
            }
        } else {
            parts.append(localization.text(.noDeadline))
        }
        let formatter = ListFormatter()
        formatter.locale = localization.locale
        return formatter.string(from: parts) ?? parts.joined(separator: ", ")
    }
}
