import Foundation
import XCTest
@testable import JottedCore

final class DeadlineCountdownTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testNearbyTimedDeadlineUsesHours() throws {
        let now = date(year: 2026, month: 7, day: 28, hour: 9, minute: 45)
        let deadline = date(year: 2026, month: 7, day: 29, hour: 11)

        XCTAssertEqual(
            DeadlineCountdown.make(
                for: deadline,
                isAllDay: false,
                now: now,
                calendar: calendar
            ),
            .hours(25)
        )
    }

    func testTimedDeadlineUnderOneHourRoundsUpToMinutes() throws {
        let now = date(year: 2026, month: 7, day: 28, hour: 9)
        let deadline = now.addingTimeInterval(42 * 60 + 10)

        XCTAssertEqual(
            DeadlineCountdown.make(
                for: deadline,
                isAllDay: false,
                now: now,
                calendar: calendar
            ),
            .minutes(43)
        )
    }

    func testTimedDeadlineUnderOneMinuteUsesLessThanMinute() throws {
        let now = date(year: 2026, month: 7, day: 28, hour: 9)
        let deadline = now.addingTimeInterval(45)

        XCTAssertEqual(
            DeadlineCountdown.make(
                for: deadline,
                isAllDay: false,
                now: now,
                calendar: calendar
            ),
            .lessThanMinute
        )
    }

    func testFarTimedDeadlineUsesCalendarDays() throws {
        let now = date(year: 2026, month: 7, day: 28, hour: 9, minute: 45)
        let deadline = date(year: 2026, month: 8, day: 21, hour: 11)

        XCTAssertEqual(
            DeadlineCountdown.make(
                for: deadline,
                isAllDay: false,
                now: now,
                calendar: calendar
            ),
            .days(24)
        )
    }

    func testTimedCountdownSwitchesFromHoursToDaysAtFortyEightHours() throws {
        let now = date(year: 2026, month: 7, day: 28, hour: 9)

        XCTAssertEqual(
            DeadlineCountdown.make(
                for: now.addingTimeInterval(47 * 60 * 60 + 59 * 60),
                isAllDay: false,
                now: now,
                calendar: calendar
            ),
            .hours(48)
        )
        XCTAssertEqual(
            DeadlineCountdown.make(
                for: now.addingTimeInterval(48 * 60 * 60),
                isAllDay: false,
                now: now,
                calendar: calendar
            ),
            .days(2)
        )
    }

    func testAllDayDeadlinesAlwaysUseCalendarDays() throws {
        let now = date(year: 2026, month: 7, day: 28, hour: 23, minute: 50)
        let tomorrow = date(year: 2026, month: 7, day: 29, hour: 12)

        XCTAssertEqual(
            DeadlineCountdown.make(
                for: tomorrow,
                isAllDay: true,
                now: now,
                calendar: calendar
            ),
            .days(1)
        )
    }

    func testAllDayDeadlineTodayUsesDueToday() throws {
        let now = date(year: 2026, month: 7, day: 28, hour: 23, minute: 50)
        let deadline = date(year: 2026, month: 7, day: 28, hour: 12)

        XCTAssertEqual(
            DeadlineCountdown.make(
                for: deadline,
                isAllDay: true,
                now: now,
                calendar: calendar
            ),
            .dueToday
        )
    }

    func testPastDeadlineHasNoCountdown() throws {
        let now = date(year: 2026, month: 7, day: 28, hour: 12)
        let deadline = date(year: 2026, month: 7, day: 28, hour: 11)

        XCTAssertNil(
            DeadlineCountdown.make(
                for: deadline,
                isAllDay: false,
                now: now,
                calendar: calendar
            )
        )
    }

    func testAllDayCalendarDistanceSurvivesDaylightSavingChange() throws {
        var londonCalendar = Calendar(identifier: .gregorian)
        londonCalendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let now = try XCTUnwrap(
            londonCalendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 23))
        )
        let deadline = try XCTUnwrap(
            londonCalendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 12))
        )

        XCTAssertEqual(
            DeadlineCountdown.make(
                for: deadline,
                isAllDay: true,
                now: now,
                calendar: londonCalendar
            ),
            .days(1)
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
