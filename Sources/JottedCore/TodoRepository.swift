import Foundation

public struct TodoRepository: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL(
        fileManager: FileManager = .default,
        applicationSupportDirectory: URL? = nil
    ) -> URL {
        let support = applicationSupportDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
                "Library/Application Support",
                isDirectory: true
            )
        return support
            .appendingPathComponent("Jotted", isDirectory: true)
            .appendingPathComponent("board.json", isDirectory: false)
    }

    public func load(fileManager: FileManager = .default) throws -> StoredBoard {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return StoredBoard(items: [])
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StoredBoard.self, from: data)
    }

    public func save(_ board: StoredBoard, fileManager: FileManager = .default) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(board)
        try data.write(to: fileURL, options: [.atomic])
    }

    @discardableResult
    public func preserveCorruptFile(fileManager: FileManager = .default, now: Date = Date()) throws -> URL? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        let stamp = ISO8601DateFormatter().string(from: now)
            .replacingOccurrences(of: ":", with: "-")
        let backup = fileURL.deletingLastPathComponent()
            .appendingPathComponent("board-corrupt-\(stamp).json")
        try fileManager.moveItem(at: fileURL, to: backup)
        return backup
    }
}
