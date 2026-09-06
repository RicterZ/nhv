import SwiftUI
import NHVCore

struct SearchView: View {
    let api: NHentaiAPI
    @Environment(LanguagePreference.self) private var language
    @State private var input = ""
    @State private var terms: [String] = []
    @State private var sort = GallerySort.date
    @State private var isSearchPresented = false

    private var query: String { terms.joined(separator: " ") }

    var body: some View {
        VStack(spacing: 0) {
            SearchTermChips(terms: terms, sort: $sort) { term in
                terms.removeAll { $0 == term }
            }

            if isSearchPresented && (terms.isEmpty || !input.isEmpty) && !SearchSyntax.suggestions(for: input).isEmpty {
                SearchSyntaxSuggestions(input: input) { syntax in
                    input = syntax.applying(to: input)
                }
            } else if terms.isEmpty {
                ContentUnavailableView("Search", systemImage: "magnifyingglass", description: Text("Find galleries by title, artist, or tag"))
            } else {
                GalleryCollectionView(api: api, query: language.applyingFilter(to: .search(query, sort)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $input, isPresented: $isSearchPresented, prompt: "Search galleries")
        .onSubmit(of: .search) {
            for term in SearchTerms.split(input) where !terms.contains(term) {
                terms.append(term)
            }
            input = ""
        }
    }
}
