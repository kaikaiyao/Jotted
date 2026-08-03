import SwiftUI

struct ModernCalendarPicker: View {
    @Binding var selection: Date
    let isAllDay: Bool
    let onSelect: () -> Void

    @State private var displayedMonth: Date
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var localization = AppLocalization.shared
    @AppStorage(AppearanceThemePreference.key) private var themeRaw = AppearanceThemePreference.defaultValue

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(
        selection: Binding<Date>,
        isAllDay: Bool,
        onSelect: @escaping () -> Void
    ) {
        _selection = selection
        self.isAllDay = isAllDay
        self.onSelect = onSelect

        let calendar = Calendar.autoupdatingCurrent
        let month = calendar.date(
            from: calendar.dateComponents([.year, .month], from: selection.wrappedValue)
        ) ?? selection.wrappedValue
        _displayedMonth = State(initialValue: month)
    }

    var body: some View {
        // Keep the open popover responsive to appearance changes.
        let _ = themeRaw

        VStack(spacing: 12) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(JottedPalette.controlForeground(for: colorScheme))
                    Text(localization.text(isAllDay ? .calendarChooseAllDay : .calendarChooseKeepingTime))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                monthNavigationButton(
                    systemName: "chevron.left",
                    offset: -1,
                    label: localization.text(.previousMonth)
                )
                monthNavigationButton(
                    systemName: "chevron.right",
                    offset: 1,
                    label: localization.text(.nextMonth)
                )
            }

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(
                            index >= 5
                                ? JottedPalette.accent(for: colorScheme).opacity(0.62)
                                : Color.secondary.opacity(0.70)
                        )
                        .frame(height: 18)
                        .accessibilityHidden(true)
                }

                ForEach(calendarDates, id: \.self) { date in
                    dayButton(for: date)
                }
            }

            HStack(spacing: 7) {
                Circle()
                    .strokeBorder(JottedPalette.accent(for: colorScheme).opacity(0.52), lineWidth: 1)
                    .frame(width: 8, height: 8)
                Text(localization.text(.todayRingExplanation))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(localization.text(.returnToToday)) {
                    displayedMonth = startOfMonth(containing: Date())
                    choose(Date())
                }
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(JottedPalette.accent(for: colorScheme))
                .buttonStyle(.plain)
                .accessibilityHint(localization.text(.chooseTodayAndClose))
            }
        }
        .padding(14)
        .frame(width: 292)
        .background {
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [
                            JottedPalette.filledAccent(for: colorScheme).opacity(0.48),
                            JottedPalette.panelTint(for: colorScheme).opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    JottedPalette.panelTint(for: colorScheme).opacity(0.30)
                    Color.white.opacity(0.58)
                    RadialGradient(
                        colors: [Color.white.opacity(0.78), Color.clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 230
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.24 : 0.98),
                            JottedPalette.accent(for: colorScheme).opacity(colorScheme == .dark ? 0.10 : 0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(
            color: colorScheme == .dark
                ? Color.black.opacity(0.32)
                : JottedPalette.filledAccent.opacity(0.105),
            radius: 24,
            y: 10
        )
        .environment(\.locale, localization.locale)
    }

    private var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = localization.locale
        calendar.firstWeekday = 2
        return calendar
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.calendar = calendar
        let sundayFirst = formatter.shortStandaloneWeekdaySymbols
            ?? formatter.shortWeekdaySymbols
            ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard sundayFirst.count == 7 else { return sundayFirst }
        return Array(sundayFirst[1...6]) + [sundayFirst[0]]
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: displayedMonth)
    }

    private var calendarDates: [Date] {
        let monthStart = startOfMonth(containing: displayedMonth)
        let weekday = calendar.component(.weekday, from: monthStart)
        let offsetFromMonday = (weekday + 5) % 7
        let gridStart = calendar.date(byAdding: .day, value: -offsetFromMonday, to: monthStart) ?? monthStart
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func dayButton(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(date)
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let day = calendar.component(.day, from: date)

        return Button {
            if !isCurrentMonth {
                displayedMonth = startOfMonth(containing: date)
            }
            choose(date)
        } label: {
            Text("\(day)")
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : JottedPalette.controlForeground(for: colorScheme).opacity(isCurrentMonth ? 0.90 : 0.30)
                )
                .frame(width: 29, height: 29)
                .background {
                    ZStack {
                        if isSelected {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            JottedPalette.accent(for: colorScheme),
                                            JottedPalette.filledAccent(for: colorScheme)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.6)
                                }
                                .shadow(color: JottedPalette.filledAccent.opacity(0.20), radius: 6, y: 3)
                        } else if isToday {
                            Circle()
                                .strokeBorder(JottedPalette.accent(for: colorScheme).opacity(0.70), lineWidth: 1.2)
                        }
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibleDate(date))
        .accessibilityValue(isSelected ? localization.text(.selected) : "")
        .accessibilityHint(
            localization.text(isCurrentMonth ? .chooseThisDate : .chooseAdjacentMonthDate)
        )
    }

    private func monthNavigationButton(systemName: String, offset: Int, label: String) -> some View {
        Button {
            guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
            withAnimation(.easeInOut(duration: 0.16)) {
                displayedMonth = startOfMonth(containing: nextMonth)
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(JottedPalette.controlForeground(for: colorScheme).opacity(0.75))
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(JottedPalette.controlFill(for: colorScheme))
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.13 : 0.84), lineWidth: 0.7)
                        }
                )
                .shadow(color: JottedPalette.filledAccent.opacity(colorScheme == .dark ? 0.12 : 0.055), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private func choose(_ date: Date) {
        let selectedTime = calendar.dateComponents([.hour, .minute], from: selection)
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.hour = isAllDay ? 12 : (selectedTime.hour ?? 18)
        components.minute = isAllDay ? 0 : (selectedTime.minute ?? 0)
        components.second = 0

        if let updated = calendar.date(from: components) {
            selection = updated
        }
        onSelect()
    }

    private func startOfMonth(containing date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func accessibleDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
