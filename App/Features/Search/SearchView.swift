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
        GalleryBrowsePage(title: Text("Search"), sort: $sort) {
            VStack(spacing: 0) {
                GallerySearchField(text: $input, isEditing: $isSearchPresented, prompt: "Search galleries") {
                    for term in SearchTerms.split(input) where !terms.contains(term) {
                        terms.append(term)
                    }
                    input = ""
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

                if !terms.isEmpty {
                    SearchTermChips(terms: terms) { term in
                        terms.removeAll { $0 == term }
                    }
                }

                if isSearchPresented && !SearchSyntax.suggestions(for: input).isEmpty {
                    SearchSyntaxSuggestions(input: input) { syntax in
                        input = syntax.applying(to: input)
                    }
                } else if terms.isEmpty {
                    ContentUnavailableView("Search", systemImage: "magnifyingglass", description: Text("Find galleries by title, artist, or tag"))
                } else {
                    GalleryCollectionView(api: api, query: language.applyingFilter(to: .search(query, sort)))
                }
            }
        }
    }
}
