import SwiftUI
import NHVCore

struct FavoritesView: View {
    let api: NHentaiAPI
    @State private var input = ""
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        GalleryCollectionView(api: api, query: .favorites(query))
            .navigationTitle("Favorites")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomSearchField(text: $input, isFocused: $isSearchFocused, prompt: "Search favorites") {
                    query = input.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            .onChange(of: input) { _, value in if value.isEmpty { query = "" } }
    }
}
