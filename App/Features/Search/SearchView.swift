import SwiftUI
import NHVCore

struct SearchView: View {
    let api: NHentaiAPI
    let stateKey: String
    @Environment(AppNavigation.self) private var navigation
    @Environment(LanguagePreference.self) private var language
    @State private var input = ""
    @State private var terms: [String] = []
    @State private var sort = GallerySort.date
    @State private var isSearchPresented = false
    @State private var completionRequest: SearchCompletionRequest?
    @State private var history = SearchHistory()
    @State private var showsInvalidID = false

    init(api: NHentaiAPI, stateKey: String = "root", savedState: AppNavigation.SearchState = .init()) {
        self.stateKey = stateKey
        _input = State(initialValue: savedState.input)
        _sort = State(initialValue: savedState.sort)
        self.api = api
        _terms = State(initialValue: savedState.terms)
    }

    private var query: String { terms.joined(separator: " ") }

    var body: some View {
        // Keep the search controller and its accessory attached to one stable
        // container when focus or sorting replaces the content underneath.
        ZStack {
            if isSearchPresented {
                GalleryScrollView(header: { filters }) {
                    searchHistory
                    if !SearchSyntax.suggestions(for: input).isEmpty {
                        SearchSyntaxSuggestions(input: input) { syntax in
                            let completion = syntax.completion(in: input)
                            input = completion.text
                            completionRequest = SearchCompletionRequest(completion: completion)
                        }
                    }
                }
            } else if terms.isEmpty {
                GalleryScrollView(header: { filters }) {
                    ContentUnavailableView("Search", systemImage: "magnifyingglass", description: Text("Find galleries by title, artist, or tag"))
                }
            } else {
                GalleryCollectionView(api: api, query: language.applyingFilter(to: .search(query, sort))) {
                    filters
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.always)
        .background(Color(uiColor: .systemBackground))
        .localizedNavigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $input, isPresented: $isSearchPresented, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search galleries")
        .modifier(SearchCompletionSelection(request: completionRequest))
        .background(SearchSortAccessory(selection: $sort, text: $input).frame(width: 0, height: 0))
        .onChange(of: AppNavigation.SearchState(terms: terms, input: input, sort: sort)) { _, state in
            navigation.saveSearch(state, key: stateKey)
        }
        .alert("Invalid gallery ID", isPresented: $showsInvalidID) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Use id: followed by a positive number using only 0–9, without other search terms.")
        }
        .onSubmit(of: .search) {
            if openDirectGallery(input) { return }
            for term in SearchTerms.split(input) where !terms.contains(term) {
                terms.append(term)
            }
            history.record(query)
            input = ""
            completionRequest = nil
            isSearchPresented = false
        }
    }

    private var searchHistory: some View {
        SearchHistoryView(history: history) { query in
            if openDirectGallery(query) { return }
            terms = SearchTerms.split(query)
            history.record(query)
            input = ""
            completionRequest = nil
            isSearchPresented = false
        }
    }

    private func openDirectGallery(_ text: String) -> Bool {
        do {
            guard let id = try GalleryLink.id(in: text) ?? SearchTerms.directGalleryID(in: text) else { return false }
            history.record("id:\(id)")
            input = ""
            completionRequest = nil
            isSearchPresented = false
            navigation.openGallery(id: id)
        } catch {
            showsInvalidID = true
        }
        return true
    }

    @ViewBuilder private var filters: some View {
        if !terms.isEmpty {
            SearchTermChips(terms: terms) { term in
                terms.removeAll { $0 == term }
            }
        }
    }
}
