import Foundation

public enum TodoPriority: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high

    public var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }
}

public struct TodoItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var deadline: Date?
    public var isAllDay: Bool
    public var priority: TodoPriority
    public var isCompleted: Bool
    public let createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        deadline: Date? = nil,
        isAllDay: Bool = false,
        priority: TodoPriority = .medium,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.deadline = deadline
        self.isAllDay = deadline != nil && isAllDay
        self.priority = priority
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    public func deadlineIsOverdue(
        at now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        guard let deadline else { return false }
        if isAllDay {
            return calendar.compare(deadline, to: now, toGranularity: .day) == .orderedAscending
        }
        return deadline < now
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case deadline
        case isAllDay
        case priority
        case isCompleted
        case createdAt
        case updatedAt
        case completedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        deadline = try container.decodeIfPresent(Date.self, forKey: .deadline)
        let storedAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        isAllDay = deadline != nil && storedAllDay
        priority = try container.decode(TodoPriority.self, forKey: .priority)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

public struct StoredBoard: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var items: [TodoItem]

    public init(schemaVersion: Int = currentSchemaVersion, items: [TodoItem]) {
        self.schemaVersion = schemaVersion
        self.items = items
    }
}
