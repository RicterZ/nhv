import SwiftUI
import NHVCore

struct SearchView: View {
    let api: NHentaiAPI
    @Environment(LanguagePreference.self) private var language
    @State private var input = ""
    @State private var terms: [String] = []
    @State private var sort = GallerySort.date
    @State private var isSearchPresented = false
    @State private var completionRequest: SearchCompletionRequest?

    private var query: String { terms.joined(separator: " ") }

    var body: some View {
        Group {
            if isSearchPresented && !SearchSyntax.suggestions(for: input).isEmpty {
                GalleryScrollView(header: { filters }) {
                    SearchSyntaxSuggestions(input: input) { syntax in
                        let completion = syntax.completion(in: input)
                        input = completion.text
                        completionRequest = SearchCompletionRequest(completion: completion)
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
        .background(Color.black)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $input, isPresented: $isSearchPresented, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search galleries")
        .modifier(SearchCompletionSelection(request: completionRequest))
        .onSubmit(of: .search) {
            for term in SearchTerms.split(input) where !terms.contains(term) {
                terms.append(term)
            }
            input = ""
            completionRequest = nil
            isSearchPresented = false
        }
    }

    private var filters: some View {
        SearchTermChips(terms: terms, sort: $sort) { term in
            terms.removeAll { $0 == term }
        }
    }
}
