import Foundation

/// A compact, human-scale description of the time remaining until a deadline.
/// Timed deadlines use clock time when they are nearby; all-day deadlines are
/// always measured in calendar days.
public enum DeadlineCountdown: Equatable, Sendable {
    case dueToday
    case lessThanMinute
    case minutes(Int)
    case hours(Int)
    case days(Int)

    private static let nearbyTimedThreshold: TimeInterval = 48 * 60 * 60

    public static func make(
        for deadline: Date,
        isAllDay: Bool,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DeadlineCountdown? {
        if isAllDay {
            let comparison = calendar.compare(deadline, to: now, toGranularity: .day)
            guard comparison != .orderedAscending else { return nil }
            guard comparison != .orderedSame else { return .dueToday }

            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: now),
                to: calendar.startOfDay(for: deadline)
            ).day ?? 1
            return .days(max(1, days))
        }

        let interval = deadline.timeIntervalSince(now)
        guard interval > 0 else { return nil }

        if interval < 60 {
            return .lessThanMinute
        }

        if interval < 60 * 60 {
            return .minutes(max(1, Int(ceil(interval / 60))))
        }

        if interval < nearbyTimedThreshold {
            return .hours(max(1, Int((interval / (60 * 60)).rounded())))
        }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: deadline)
        ).day ?? 1
        return .days(max(1, days))
    }
}
