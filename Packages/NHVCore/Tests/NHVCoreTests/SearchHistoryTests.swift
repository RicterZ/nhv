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

@Test @MainActor func searchHistoryKeepsTwentyMostRecentQueries() throws {
    let suite = "SearchHistoryTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let history = SearchHistory(defaults: defaults)
    for number in 0..<25 { history.record("tag:\(number)") }
    #expect(history.queries == (5..<25).reversed().map { "tag:\($0)" })
    history.record("tag:10")
    #expect(history.queries.first == "tag:10")
    #expect(history.queries.count == 20)
}
