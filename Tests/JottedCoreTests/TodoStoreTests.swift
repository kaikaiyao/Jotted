import Foundation
import XCTest
@testable import JottedCore

@MainActor
final class TodoStoreTests: XCTestCase {
    func testAddPersistsAndReloads() throws {
        let (repository, directory) = makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }

        let deadline = Date(timeIntervalSince1970: 1_900_000_000)
        let store = TodoStore(repository: repository)
        let item = store.add(
            title: "  提交论文  ",
            deadline: deadline,
            priority: .high,
            isAllDay: true
        )

        XCTAssertEqual(item?.title, "提交论文")
        XCTAssertEqual(store.items.count, 1)
        XCTAssertNil(store.saveIssue)

        let reloaded = TodoStore(repository: repository)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.title, "提交论文")
        XCTAssertEqual(reloaded.items.first?.priority, .high)
        XCTAssertEqual(reloaded.items.first?.isAllDay, true)
        let reloadedDeadline = try XCTUnwrap(reloaded.items.first?.deadline)
        XCTAssertEqual(reloadedDeadline.timeIntervalSince1970, deadline.timeIntervalSince1970, accuracy: 1)
    }

    func testBlankTitleIsRejected() throws {
        let (repository, directory) = makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = TodoStore(repository: repository)
        XCTAssertNil(store.add(title: " \n ", deadline: nil, priority: .low))
        XCTAssertTrue(store.items.isEmpty)
    }

    func testToggleCompletionAndRestore() throws {
        let (repository, directory) = makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = TodoStore(repository: repository)
        let original = try XCTUnwrap(store.add(title: "完成测试", deadline: nil, priority: .medium))

        store.toggleCompletion(original)
        XCTAssertTrue(try XCTUnwrap(store.items.first).isCompleted)
        XCTAssertNotNil(store.items.first?.completedAt)

        store.restore(original)
        XCTAssertFalse(try XCTUnwrap(store.items.first).isCompleted)
        XCTAssertNil(store.items.first?.completedAt)
    }

    func testPendingSortsByDeadlineThenPriority() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let later = TodoItem(title: "更晚", deadline: now.addingTimeInterval(7_200), priority: .high, createdAt: now)
        let earlier = TodoItem(title: "更早", deadline: now.addingTimeInterval(3_600), priority: .low, createdAt: now)
        let undatedLow = TodoItem(title: "无日期低", deadline: nil, priority: .low, createdAt: now)
        let undatedHigh = TodoItem(title: "无日期高", deadline: nil, priority: .high, createdAt: now)

        let sorted = TodoStore.sorted([undatedLow, later, undatedHigh, earlier])
        XCTAssertEqual(sorted.map(\.title), ["更早", "更晚", "无日期高", "无日期低"])
    }

    func testLegacyItemWithoutAllDayFieldStillLoadsAsTimed() throws {
        let (repository, directory) = makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let legacy = LegacyStoredBoard(
            schemaVersion: 1,
            items: [
                LegacyTodoItem(
                    id: UUID(),
                    title: "旧事项",
                    deadline: now,
                    priority: .medium,
                    isCompleted: false,
                    createdAt: now,
                    updatedAt: now,
                    completedAt: nil
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(legacy).write(to: repository.fileURL)

        let store = TodoStore(repository: repository)
        XCTAssertEqual(store.items.first?.title, "旧事项")
        XCTAssertEqual(store.items.first?.isAllDay, false)
        XCTAssertNil(store.loadIssue)
    }

    func testAllDayDeadlineDoesNotBecomeOverdueUntilNextCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let deadline = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26, hour: 12))!
        let sameDayLate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26, hour: 23, minute: 59))!
        let nextDay = calendar.date(from: DateComponents(year: 2026, month: 7, day: 27, hour: 0, minute: 1))!
        let item = TodoItem(title: "全天事项", deadline: deadline, isAllDay: true)

        XCTAssertFalse(item.deadlineIsOverdue(at: sameDayLate, calendar: calendar))
        XCTAssertTrue(item.deadlineIsOverdue(at: nextDay, calendar: calendar))
    }

    func testTimedDeadlineCanBecomeOverdueDuringSameDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let deadline = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26, hour: 9))!
        let later = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26, hour: 10))!
        let item = TodoItem(title: "定时事项", deadline: deadline)

        XCTAssertTrue(item.deadlineIsOverdue(at: later, calendar: calendar))
    }

    func testSameDayTimedItemsSortBeforeAllDayDeadline() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26, hour: 9))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26, hour: 18))!
        let allDayMarker = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26, hour: 12))!
        let morningItem = TodoItem(title: "上午", deadline: morning)
        let eveningItem = TodoItem(title: "傍晚", deadline: evening)
        let allDayItem = TodoItem(title: "全天", deadline: allDayMarker, isAllDay: true)

        let sorted = TodoStore.sorted([allDayItem, eveningItem, morningItem], calendar: calendar)

        XCTAssertEqual(sorted.map(\.title), ["上午", "傍晚", "全天"])
    }

    func testCorruptFileIsPreservedInsteadOfOverwritten() throws {
        let (repository, directory) = makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: repository.fileURL)

        let store = TodoStore(repository: repository)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNotNil(store.loadIssue)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.fileURL.path))
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(backups.filter { $0.hasPrefix("board-corrupt-") }.count, 1)
    }

    func testDefaultRepositoryUsesJottedApplicationSupportDirectory() {
        let supportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JottedDefaultPathTests-\(UUID().uuidString)", isDirectory: true)

        let selectedURL = TodoRepository.defaultFileURL(
            applicationSupportDirectory: supportDirectory
        )

        XCTAssertEqual(
            selectedURL,
            supportDirectory
                .appendingPathComponent("Jotted", isDirectory: true)
                .appendingPathComponent("board.json")
        )
    }

    private func makeRepository() -> (TodoRepository, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JottedTests-\(UUID().uuidString)", isDirectory: true)
        return (
            TodoRepository(fileURL: directory.appendingPathComponent("board.json")),
            directory
        )
    }
}

private struct LegacyStoredBoard: Codable {
    let schemaVersion: Int
    let items: [LegacyTodoItem]
}

private struct LegacyTodoItem: Codable {
    let id: UUID
    let title: String
    let deadline: Date?
    let priority: TodoPriority
    let isCompleted: Bool
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
}
