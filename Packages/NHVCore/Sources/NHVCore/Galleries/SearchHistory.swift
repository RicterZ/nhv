import Foundation
import Observation

@MainActor
@Observable
public final class SearchHistory {
    public private(set) var queries: [String]
    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "searchHistory.queries"
    private static let limit = 10

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // SwiftUI can construct this store while rebuilding a view. Keep init
        // read-only: defaults writes would invalidate other @AppStorage views.
        // The next explicit record/clear persists the bounded history.
        queries = Array((defaults.stringArray(forKey: Self.key) ?? []).prefix(Self.limit))
    }

    public func record(_ query: String) {
        let normalized = SearchTerms.split(query).joined(separator: " ")
        guard !normalized.isEmpty else { return }
        queries.removeAll { $0 == normalized }
        queries.insert(normalized, at: 0)
        queries = Array(queries.prefix(Self.limit))
        defaults.set(queries, forKey: Self.key)
    }

    public func clear() {
        queries = []
        defaults.removeObject(forKey: Self.key)
    }
}
