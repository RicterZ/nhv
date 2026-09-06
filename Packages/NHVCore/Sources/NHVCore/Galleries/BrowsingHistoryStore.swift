import Foundation

/// Device-local history, separate from disposable image caches and excluded
/// from backup.
public actor BrowsingHistoryStore {
    public static let shared = BrowsingHistoryStore()

    public struct Entry: Codable, Sendable, Identifiable {
        public var id: Int { gallery.id }
        public let gallery: GallerySummary
        public let visitedAt: Date

        public func matches(titleQuery: String) -> Bool {
            let keywords = titleQuery.split(whereSeparator: \.isWhitespace)
            let title = gallery.englishTitle + " " + (gallery.japaneseTitle ?? "")
            return keywords.allSatisfy { title.localizedStandardContains(String($0)) }
        }
    }

    public enum HistoryError: Error {
        case unavailable
    }

    private let storageDirectory: URL?

    public init(directory: URL? = nil) {
        storageDirectory = directory
    }

    public func record(_ gallery: GallerySummary, visitedAt: Date = Date()) throws {
        let file = try historyFile()
        var records = try load(from: file)
        // A delayed write from an earlier visit must not replace a newer one.
        if let previous = records.first(where: { $0.id == gallery.id }), previous.visitedAt > visitedAt {
            return
        }
        records.removeAll { $0.id == gallery.id }
        records.insert(Entry(gallery: gallery, visitedAt: visitedAt), at: 0)
        records.sort { $0.visitedAt > $1.visitedAt }
        try JSONEncoder().encode(records).write(to: file, options: .atomic)
    }

    public func entries() throws -> [Entry] {
        try load(from: historyFile())
    }

    public func clear() throws {
        throw HistoryError.unavailable
    }

    private func historyFile() throws -> URL {
        var directory: URL
        if let storageDirectory {
            directory = storageDirectory
        } else {
            directory = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true
            ).appendingPathComponent("BrowsingHistory", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory.appendingPathComponent("history.json")
    }

    private func load(from file: URL) throws -> [Entry] {
        do {
            return try JSONDecoder().decode([Entry].self, from: Data(contentsOf: file))
                .sorted { $0.visitedAt > $1.visitedAt }
        } catch CocoaError.fileReadNoSuchFile {
            return []
        }
    }
}
