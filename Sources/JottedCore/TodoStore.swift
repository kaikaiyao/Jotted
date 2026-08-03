import Combine
import Foundation

@MainActor
public final class TodoStore: ObservableObject {
    @Published public private(set) var items: [TodoItem] = [] {
        didSet { rebuildDerivedItems() }
    }

    /// Sorted, filtered projections of `items`.
    ///
    /// These used to be computed properties, so every SwiftUI body evaluation
    /// re-ran a filter *and* a full sort — several times per frame while the
    /// board was on screen. Caching them on mutation makes reads free.
    @Published public private(set) var pendingItems: [TodoItem] = []
    @Published public private(set) var completedItems: [TodoItem] = []

    @Published public private(set) var loadIssue: String?
    @Published public private(set) var saveIssue: String?

    public let repository: TodoRepository

    public init(repository: TodoRepository = TodoRepository(fileURL: TodoRepository.defaultFileURL()), loadImmediately: Bool = true) {
        self.repository = repository
        if loadImmediately {
            load()
        }
    }

    private func rebuildDerivedItems() {
        pendingItems = Self.sorted(items.filter { !$0.isCompleted })
        completedItems = items
            .filter(\.isCompleted)
            .sorted {
                ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt)
            }
    }

    public func load() {
        do {
            items = try repository.load().items
            loadIssue = nil
        } catch {
            do {
                let backup = try repository.preserveCorruptFile()
                items = []
                if let backup {
                    loadIssue = "原数据无法读取，已保留为 \(backup.lastPathComponent)"
                } else {
                    loadIssue = "数据读取失败：\(error.localizedDescription)"
                }
            } catch {
                items = []
                loadIssue = "数据读取失败，且无法备份原文件：\(error.localizedDescription)"
            }
        }
    }

    @discardableResult
    public func add(
        title: String,
        deadline: Date?,
        priority: TodoPriority,
        isAllDay: Bool = false
    ) -> TodoItem? {
        let cleanTitle = Self.clean(title)
        guard !cleanTitle.isEmpty else { return nil }

        let now = Date()
        let item = TodoItem(
            title: cleanTitle,
            deadline: deadline,
            isAllDay: isAllDay,
            priority: priority,
            createdAt: now,
            updatedAt: now
        )
        items.append(item)
        persist()
        return item
    }

    public func update(
        _ item: TodoItem,
        title: String,
        deadline: Date?,
        priority: TodoPriority,
        isAllDay: Bool
    ) {
        let cleanTitle = Self.clean(title)
        guard !cleanTitle.isEmpty, let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        items[index].title = cleanTitle
        items[index].deadline = deadline
        items[index].isAllDay = deadline != nil && isAllDay
        items[index].priority = priority
        items[index].updatedAt = Date()
        persist()
    }

    public func toggleCompletion(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let now = Date()
        items[index].isCompleted.toggle()
        items[index].completedAt = items[index].isCompleted ? now : nil
        items[index].updatedAt = now
        persist()
    }

    public func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    public func restore(_ item: TodoItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        persist()
    }

    public func clearCompleted() {
        items.removeAll(where: \.isCompleted)
        persist()
    }

    public static func sorted(
        _ items: [TodoItem],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [TodoItem] {
        items.sorted { lhs, rhs in
            switch (lhs.deadline, rhs.deadline) {
            case let (left?, right?):
                let dayOrder = calendar.compare(left, to: right, toGranularity: .day)
                if dayOrder != .orderedSame {
                    return dayOrder == .orderedAscending
                }
                if lhs.isAllDay != rhs.isAllDay {
                    return !lhs.isAllDay
                }
                if !lhs.isAllDay, left != right {
                    return left < right
                }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }
            if lhs.priority.rank != rhs.priority.rank {
                return lhs.priority.rank > rhs.priority.rank
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private func persist() {
        do {
            try repository.save(StoredBoard(items: items))
            saveIssue = nil
        } catch {
            saveIssue = "保存失败：\(error.localizedDescription)"
        }
    }

    private static func clean(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
