import Foundation
import Observation

@MainActor @Observable
public final class AppNavigation {
    public enum Tab: String, Codable, Hashable { case home, search, favorites, settings }
    public struct Route: Codable, Hashable, Identifiable {
        public enum Kind: Codable, Hashable { case gallery(Int), search(String), history }
        public let id: UUID
        public let kind: Kind
        public var recordsVisit: Bool
        public init(_ kind: Kind, recordsVisit: Bool = true) {
            self.id = UUID(); self.kind = kind; self.recordsVisit = recordsVisit
        }
    }
    public struct SearchState: Codable, Equatable {
        public var terms: [String]
        public var input: String
        public var sort: GallerySort
        public init(terms: [String] = [], input: String = "", sort: GallerySort = .date) {
            self.terms = terms; self.input = input; self.sort = sort
        }
    }
    public struct ReaderState: Codable, Identifiable {
        public let id: UUID
        public let galleryID: Int
        public let pages: [GalleryPage]
        public var initialIndex: Int
        public init(galleryID: Int, pages: [GalleryPage], initialIndex: Int) {
            id = UUID(); self.galleryID = galleryID; self.pages = pages
            self.initialIndex = max(0, min(initialIndex, pages.count - 1))
        }
    }
    private struct Snapshot: Codable {
        var selectedTab = Tab.home
        var paths: [Tab: [Route]] = [:]
        var searches: [String: SearchState] = [:]
        var favoritesInput = ""
        var favoritesQuery = ""
        var historyQuery = ""
        var reader: ReaderState?
    }
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String
    private var snapshot: Snapshot { didSet { persist() } }
    public var isReading = false
    public private(set) var summaries: [Int: GallerySummary] = [:]

    public init(accountID: Int, defaults: UserDefaults = .standard) {
        self.defaults = defaults; key = "navigation.account.\(accountID)"
        snapshot = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) } ?? Snapshot()
        if let reader = snapshot.reader,
           reader.pages.isEmpty || !reader.pages.indices.contains(reader.initialIndex) { snapshot.reader = nil }
        isReading = snapshot.reader != nil
    }
    public var selectedTab: Tab {
        get { snapshot.selectedTab }
        set { snapshot.selectedTab = newValue }
    }
    public var reader: ReaderState? {
        get { snapshot.reader }
        set { snapshot.reader = newValue; isReading = newValue != nil }
    }
    public var favoritesInput: String {
        get { snapshot.favoritesInput }
        set { snapshot.favoritesInput = newValue }
    }
    public var favoritesQuery: String {
        get { snapshot.favoritesQuery }
        set { snapshot.favoritesQuery = newValue }
    }
    public var historyQuery: String {
        get { snapshot.historyQuery }
        set { snapshot.historyQuery = newValue }
    }
    public func path(for tab: Tab) -> [Route] { snapshot.paths[tab] ?? [] }
    public func setPath(_ path: [Route], for tab: Tab) { snapshot.paths[tab] = path }
    public func push(_ route: Route) { snapshot.paths[selectedTab, default: []].append(route) }
    public func searchState(_ key: String, initialQuery: String = "") -> SearchState {
        snapshot.searches[key] ?? SearchState(terms: SearchTerms.split(initialQuery))
    }
    public func saveSearch(_ state: SearchState, key: String) { snapshot.searches[key] = state }
    public func openGallery(_ summary: GallerySummary, recordsVisit: Bool = true) {
        summaries[summary.id] = summary
        push(Route(.gallery(summary.id), recordsVisit: recordsVisit))
    }
    public func openGallery(id: Int) { push(Route(.gallery(id))) }
    public func updateReaderPage(_ index: Int) {
        guard let reader = snapshot.reader, reader.pages.indices.contains(index) else { return }
        snapshot.reader?.initialIndex = index
    }
    private func persist() {
        var saved = snapshot
        // Reconstructing an existing route must not count as another visit.
        saved.paths = saved.paths.mapValues { $0.map { route in
            var copy = route; copy.recordsVisit = false; return copy
        } }
        let searchKeys = Set(saved.paths.values.flatMap { $0 }.map { $0.id.uuidString }).union(["root"])
        saved.searches = saved.searches.filter { searchKeys.contains($0.key) }
        guard let data = try? JSONEncoder().encode(saved) else { return }
        defaults.set(data, forKey: key)
    }
}
