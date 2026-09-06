import Foundation
import Testing
@testable import NHVCore

@Test @MainActor func searchHistoryPersistsDeduplicatesAndClears() throws {
    let suite = "SearchHistoryTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let history = SearchHistory(defaults: defaults)
    history.record(" \n ")
    #expect(history.queries.isEmpty)
    history.record(" artist:\"some  artist\"  -language:japanese ")
    history.record("tag:example")
    history.record("artist:\"some  artist\" -language:japanese")
    #expect(history.queries == ["artist:\"some  artist\" -language:japanese", "tag:example"])
    #expect(SearchHistory(defaults: defaults).queries == history.queries)
    history.clear()
    #expect(history.queries.isEmpty)
    #expect(SearchHistory(defaults: defaults).queries.isEmpty)
}

@Test @MainActor func searchHistoryKeepsTenMostRecentQueries() throws {
    let suite = "SearchHistoryTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let history = SearchHistory(defaults: defaults)
    for number in 0..<25 { history.record("tag:\(number)") }
    #expect(history.queries == (15..<25).reversed().map { "tag:\($0)" })
    history.record("tag:10")
    #expect(history.queries.first == "tag:10")
    #expect(history.queries.count == 10)
    #expect(SearchHistory(defaults: defaults).queries == history.queries)
}

private final class WriteTrackingDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private var writes = 0

    var writeCount: Int { lock.withLock { writes } }

    override func set(_ value: Any?, forKey defaultName: String) {
        lock.withLock { writes += 1 }
        super.set(value, forKey: defaultName)
    }
}

@Test @MainActor func rebuildingSearchHistoryNeverWritesDefaults() throws {
    let suite = "SearchHistoryTests.\(UUID().uuidString)"
    let defaults = try #require(WriteTrackingDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    #expect(SearchHistory(defaults: defaults).queries.isEmpty)
    #expect(defaults.writeCount == 0)

    let saved = (0..<20).map { "tag:\($0)" }
    defaults.set(saved, forKey: "searchHistory.queries")
    let initialWrites = defaults.writeCount
    // A set of the same value can still notify @AppStorage and rebuild views.
    // Check actual write calls, not just equality of the persisted array.
    for _ in 0..<20 {
        #expect(SearchHistory(defaults: defaults).queries == Array(saved.prefix(10)))
    }
    #expect(defaults.writeCount == initialWrites)
    #expect(defaults.stringArray(forKey: "searchHistory.queries") == saved)

    let history = SearchHistory(defaults: defaults)
    history.record("tag:new")
    #expect(defaults.stringArray(forKey: "searchHistory.queries") == ["tag:new"] + Array(saved.prefix(9)))
    #expect(defaults.writeCount == initialWrites + 1)
}
