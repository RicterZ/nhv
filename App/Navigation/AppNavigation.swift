import Foundation
import Observation

@MainActor @Observable
final class AppNavigation {
    enum Tab: Hashable {
        case home, search, favorites, settings
    }

    struct SearchRequest {
        let id = UUID()
        let query: String
    }

    var selectedTab = Tab.home
    private(set) var searchRequest = SearchRequest(query: "")

    func openSearch(query: String) {
        // A fresh request resets the search stack even when the tag was
        // tapped inside a detail already pushed onto the Search tab.
        searchRequest = SearchRequest(query: query)
        selectedTab = .search
    }
}
