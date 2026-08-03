import Foundation
import JottedCore
import SwiftUI

enum DeadlineTone {
    case overdue
    case today
    case soon
    case future

    func color(for scheme: ColorScheme) -> Color {
        switch self {
        case .overdue: JottedPalette.danger(for: scheme)
        case .today: JottedPalette.warning(for: scheme)
        case .soon: JottedPalette.accent(for: scheme)
        case .future: Color.secondary
        }
    }
}

struct DeadlinePresentation {
    let text: String
    let accessibilityText: String
    let symbol: String
    let tone: DeadlineTone
    let countdownText: String?

    init(
        text: String,
        accessibilityText: String,
        symbol: String,
        tone: DeadlineTone,
        countdownText: String? = nil
    ) {
        self.text = text
        self.accessibilityText = accessibilityText
        self.symbol = symbol
        self.tone = tone
        self.countdownText = countdownText
    }

    static func make(
        for deadline: Date,
        isAllDay: Bool = false,
        now: Date,
        language: AppLanguage = .system,
        locale: Locale? = nil,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DeadlinePresentation {
        let resolvedLanguage = language.resolved
        let presentationLocale = locale ?? resolvedLanguage.locale

        let basePresentation: DeadlinePresentation
        if isAllDay {
            basePresentation = makeAllDay(
                for: deadline,
                now: now,
                language: resolvedLanguage,
                locale: presentationLocale,
                calendar: calendar
            )
        } else {
            basePresentation = makeTimed(
                for: deadline,
                now: now,
                language: resolvedLanguage,
                locale: presentationLocale,
                calendar: calendar
            )
        }

        guard let countdown = DeadlineCountdown.make(
            for: deadline,
            isAllDay: isAllDay,
            now: now,
            calendar: calendar
        ) else {
            return basePresentation
        }

        return DeadlinePresentation(
            text: basePresentation.text,
            accessibilityText: basePresentation.accessibilityText,
            symbol: basePresentation.symbol,
            tone: basePresentation.tone,
            countdownText: localizedCountdown(countdown, language: resolvedLanguage)
        )
    }

    private static func makeTimed(
        for deadline: Date,
        now: Date,
        language: AppLanguage,
        locale: Locale,
        calendar: Calendar
    ) -> DeadlinePresentation {

        let time = deadline.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(locale)
        )

        if deadline < now {
            if calendar.isDate(deadline, inSameDayAs: now) {
                return DeadlinePresentation(
                    text: L10n.text(.overdueAt(time), language: language),
                    accessibilityText: L10n.text(.overdueAtAccessibility(time), language: language),
                    symbol: "exclamationmark.circle.fill",
                    tone: .overdue
                )
            }

            let deadlineDay = calendar.startOfDay(for: deadline)
            let today = calendar.startOfDay(for: now)
            let days = max(1, calendar.dateComponents([.day], from: deadlineDay, to: today).day ?? 1)
            return DeadlinePresentation(
                text: L10n.text(.overdueDays(days), language: language),
                accessibilityText: L10n.text(.overdueDays(days), language: language),
                symbol: "exclamationmark.circle.fill",
                tone: .overdue
            )
        }

        if calendar.isDate(deadline, inSameDayAs: now) {
            return DeadlinePresentation(
                text: L10n.text(.dueTodayAt(time), language: language),
                accessibilityText: L10n.text(.dueTodayAtAccessibility(time), language: language),
                symbol: "clock.fill",
                tone: .today
            )
        }

        if isDateTomorrow(deadline, relativeTo: now, calendar: calendar) {
            return DeadlinePresentation(
                text: L10n.text(.dueTomorrowAt(time), language: language),
                accessibilityText: L10n.text(.dueTomorrowAtAccessibility(time), language: language),
                symbol: "calendar",
                tone: .soon
            )
        }

        let dayDistance = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: deadline)
        ).day ?? 99

        if dayDistance <= 6 {
            let weekday = deadline.formatted(
                Date.FormatStyle().weekday(.wide).locale(locale)
            )
            return DeadlinePresentation(
                text: L10n.text(.dueWeekdayAt(weekday, time), language: language),
                accessibilityText: L10n.text(
                    .dueWeekdayAtAccessibility(weekday, time),
                    language: language
                ),
                symbol: "calendar",
                tone: .soon
            )
        }

        let date = deadline.formatted(
            Date.FormatStyle()
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
                .locale(locale)
        )
        return DeadlinePresentation(
            text: L10n.text(.dueDate(date), language: language),
            accessibilityText: L10n.text(.dueDateAccessibility(date), language: language),
            symbol: "calendar",
            tone: .future
        )
    }

    private static func localizedCountdown(
        _ countdown: DeadlineCountdown,
        language: AppLanguage
    ) -> String {
        let key: L10n.Key
        switch countdown {
        case .dueToday:
            key = .remainingDueToday
        case .lessThanMinute:
            key = .remainingLessThanMinute
        case let .minutes(value):
            key = .remainingMinutes(value)
        case let .hours(value):
            key = .remainingHours(value)
        case let .days(value):
            key = .remainingDays(value)
        }
        return L10n.text(key, language: language)
    }

    private static func makeAllDay(
        for deadline: Date,
        now: Date,
        language: AppLanguage,
        locale: Locale,
        calendar: Calendar
    ) -> DeadlinePresentation {
        let comparison = calendar.compare(deadline, to: now, toGranularity: .day)
        if comparison == .orderedAscending {
            let deadlineDay = calendar.startOfDay(for: deadline)
            let today = calendar.startOfDay(for: now)
            let days = max(1, calendar.dateComponents([.day], from: deadlineDay, to: today).day ?? 1)
            return DeadlinePresentation(
                text: L10n.text(.overdueDays(days), language: language),
                accessibilityText: L10n.text(.allDayOverdueAccessibility(days), language: language),
                symbol: "exclamationmark.circle.fill",
                tone: .overdue
            )
        }

        if comparison == .orderedSame {
            return DeadlinePresentation(
                text: L10n.text(.allDayToday, language: language),
                accessibilityText: L10n.text(.allDayTodayAccessibility, language: language),
                symbol: "calendar",
                tone: .today
            )
        }

        if isDateTomorrow(deadline, relativeTo: now, calendar: calendar) {
            return DeadlinePresentation(
                text: L10n.text(.allDayTomorrow, language: language),
                accessibilityText: L10n.text(.allDayTomorrowAccessibility, language: language),
                symbol: "calendar",
                tone: .soon
            )
        }

        let dayDistance = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: deadline)
        ).day ?? 99

        if dayDistance <= 6 {
            let weekday = deadline.formatted(
                Date.FormatStyle().weekday(.wide).locale(locale)
            )
            return DeadlinePresentation(
                text: L10n.text(.allDayWeekday(weekday), language: language),
                accessibilityText: L10n.text(.allDayWeekdayAccessibility(weekday), language: language),
                symbol: "calendar",
                tone: .soon
            )
        }

        let date = deadline.formatted(
            Date.FormatStyle()
                .month(.abbreviated)
                .day()
                .locale(locale)
        )
        return DeadlinePresentation(
            text: L10n.text(.allDayDate(date), language: language),
            accessibilityText: L10n.text(.allDayDateAccessibility(date), language: language),
            symbol: "calendar",
            tone: .future
        )
    }

    private static func isDateTomorrow(
        _ date: Date,
        relativeTo now: Date,
        calendar: Calendar
    ) -> Bool {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return false
        }
        return calendar.isDate(date, inSameDayAs: tomorrow)
    }
}
