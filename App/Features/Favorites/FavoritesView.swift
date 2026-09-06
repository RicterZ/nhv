import SwiftUI
import NHVCore

struct FavoritesView: View {
    let api: NHentaiAPI
    @State private var input = ""
    @State private var query = ""

    var body: some View {
        GalleryCollectionView(api: api, query: .favorites(query))
            .navigationTitle("Favorites")
            .searchable(text: $input, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search favorites")
            .onSubmit(of: .search) { query = input.trimmingCharacters(in: .whitespacesAndNewlines) }
            .onChange(of: input) { _, value in if value.isEmpty { query = "" } }
    }
}
