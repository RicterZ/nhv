import SwiftUI
import NHVCore

struct SearchView: View {
    let api: NHentaiAPI
    let stateKey: String
    @Environment(AppNavigation.self) private var navigation
    @Environment(LanguagePreference.self) private var language
    @Environment(TagTranslationStore.self) private var tagTranslations
    @AppStorage(ContentDisplayPreference.translatesTagsKey) private var translatesTags = false
    @State private var input = ""
    @State private var terms: [String] = []
    @State private var sort = GallerySort.date
    @State private var isSearchPresented = false
    @State private var completionRequest: SearchCompletionRequest?
    @State private var history = SearchHistory()
    @State private var showsInvalidID = false
    @State private var selectedTagSuggestion: TagTranslationStore.Suggestion?
    @State private var tagSuggestions: [TagTranslationStore.Suggestion] = []

    init(api: NHentaiAPI, stateKey: String = "root", savedState: AppNavigation.SearchState = .init()) {
        self.stateKey = stateKey
        _input = State(initialValue: savedState.input)
        _sort = State(initialValue: savedState.sort)
        self.api = api
        _terms = State(initialValue: savedState.terms)
    }

    private var query: String { terms.joined(separator: " ") }
    private var usesTranslatedTags: Bool {
        language.selection == .simplifiedChinese && translatesTags
    }
    private var tagSuggestionRequest: TagSuggestionRequest {
        TagSuggestionRequest(input: input, includesTranslations: usesTranslatedTags,
            isPresented: isSearchPresented, isReady: tagTranslations.isReady)
    }

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
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !tagSuggestions.isEmpty {
                        TagAutocompleteSuggestions(suggestions: tagSuggestions, showsTranslations: usesTranslatedTags) {
                            input = $0.displayQuery
                            selectedTagSuggestion = $0
                            tagSuggestions = []
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
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
        .onChange(of: input) { _, value in
            if selectedTagSuggestion?.displayQuery != value { selectedTagSuggestion = nil }
        }
        .task(id: tagSuggestionRequest) {
            guard tagSuggestionRequest.shouldSearch,
                  selectedTagSuggestion?.displayQuery != input
            else {
                tagSuggestions = []
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            tagSuggestions = tagTranslations.suggestions(
                for: input, includesTranslations: usesTranslatedTags)
        }
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
            let submittedInput: String
            if let selectedTagSuggestion, selectedTagSuggestion.displayQuery == input {
                submittedInput = selectedTagSuggestion.searchQuery
            } else {
                submittedInput = tagTranslations.resolvedQuery(for: input, includesTranslations: usesTranslatedTags)
            }
            for term in SearchTerms.split(submittedInput) where !terms.contains(term) {
                terms.append(term)
            }
            history.record(query)
            input = ""
            selectedTagSuggestion = nil
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
            selectedTagSuggestion = nil
            completionRequest = nil
            isSearchPresented = false
        }
    }

    private func openDirectGallery(_ text: String) -> Bool {
        do {
            guard let id = try GalleryLink.id(in: text) ?? SearchTerms.directGalleryID(in: text) else { return false }
            history.record("id:\(id)")
            input = ""
            selectedTagSuggestion = nil
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

private struct TagSuggestionRequest: Equatable {
    let input: String
    let includesTranslations: Bool
    let isPresented: Bool
    let isReady: Bool

    var shouldSearch: Bool {
        isPresented && isReady && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
