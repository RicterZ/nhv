import Foundation
import Testing
@testable import NHVCore

private func historyGallery(_ id: Int, title: String = "Fixture", japaneseTitle: String = "") throws -> GallerySummary {
    let data = try JSONSerialization.data(withJSONObject: [
        "id": id, "mediaId": String(id), "englishTitle": title, "japaneseTitle": japaneseTitle,
        "thumbnail": "/galleries/\(id)/thumb.webp", "thumbnailWidth": 200, "thumbnailHeight": 300
    ])
    return try JSONDecoder().decode(GallerySummary.self, from: data)
}

@Test func browsingHistorySortsByVisitTimeAndIgnoresDelayedOlderVisits() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let history = BrowsingHistoryStore(directory: directory)
    try await history.record(historyGallery(1), visitedAt: Date(timeIntervalSince1970: 30))
    try await history.record(historyGallery(2), visitedAt: Date(timeIntervalSince1970: 10))
    try await history.record(historyGallery(3), visitedAt: Date(timeIntervalSince1970: 20))
    try await history.record(historyGallery(1, title: "Stale"), visitedAt: Date(timeIntervalSince1970: 5))
    let records = try await BrowsingHistoryStore(directory: directory).entries()
    #expect(records.map(\.id) == [1, 3, 2])
    #expect(records.first?.visitedAt == Date(timeIntervalSince1970: 30))
    #expect(records.first?.gallery.englishTitle == "Fixture")
}

@Test func browsingHistorySearchMatchesLocalTitlesAndAllKeywords() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let history = BrowsingHistoryStore(directory: directory)
    try await history.record(historyGallery(1, title: "Summer Café", japaneseTitle: "夏の物語"))
    try await history.record(historyGallery(2, title: "Winter"))
    let records = try await history.entries()
    #expect(records.filter { $0.matches(titleQuery: "  SUMMER cafe \n") }.map(\.id) == [1])
    #expect(records.filter { $0.matches(titleQuery: "夏の物語") }.map(\.id) == [1])
    #expect(records.filter { $0.matches(titleQuery: "winter summer") }.isEmpty)
    #expect(records.filter { $0.matches(titleQuery: "\n  ") }.count == 2)
    #expect(records.filter { $0.matches(titleQuery: "galleries") }.isEmpty)
}

@Test func browsingHistoryPersistsAndMovesRevisitedGalleryToFront() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let history = BrowsingHistoryStore(directory: directory)
    #expect(try await history.entries().isEmpty)
    try await history.record(historyGallery(1), visitedAt: Date(timeIntervalSince1970: 10))
    try await history.record(historyGallery(2), visitedAt: Date(timeIntervalSince1970: 20))
    try await history.record(historyGallery(1, title: "Updated"), visitedAt: Date(timeIntervalSince1970: 30))

    let reopened = BrowsingHistoryStore(directory: directory)
    let records = try await reopened.entries()
    #expect(records.map(\.id) == [1, 2])
    #expect(records.first?.gallery.englishTitle == "Updated")
    #expect(records.first?.visitedAt == Date(timeIntervalSince1970: 30))
    #expect(records.first?.gallery.thumbnail == "/galleries/1/thumb.webp")
    #expect(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
}

@Test func browsingHistorySerializesConcurrentWrites() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let history = BrowsingHistoryStore(directory: directory)
    try await withThrowingTaskGroup(of: Void.self) { group in
        for id in 1...20 {
            let gallery = try historyGallery(id)
            group.addTask { try await history.record(gallery) }
        }
        try await group.waitForAll()
    }
    let records = try await BrowsingHistoryStore(directory: directory).entries()
    #expect(Set(records.map(\.id)) == Set(1...20))
    #expect(records.count == 20)
}

@Test func browsingHistoryDoesNotOverwriteUnreadableHistory() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("history.json")
    let original = Data("invalid history".utf8)
    try original.write(to: file)
    let history = BrowsingHistoryStore(directory: directory)
    await #expect(throws: (any Error).self) {
        try await history.record(historyGallery(1))
    }
    #expect(try Data(contentsOf: file) == original)
}
