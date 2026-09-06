import SwiftUI
import NHVCore

struct SearchView: View {
    let api: NHentaiAPI
    @State private var input = ""
    @State private var query = ""
    @State private var sort = GallerySort.date

    var body: some View {
        Group {
            if query.isEmpty {
                ContentUnavailableView("Search", systemImage: "magnifyingglass", description: Text("Find galleries by title, artist, or tag"))
            } else {
                GalleryCollectionView(api: api, query: .search(query, sort))
            }
        }
        .navigationTitle("Search")
        .searchable(text: $input, prompt: "Search galleries")
        .onSubmit(of: .search) { query = input.trimmingCharacters(in: .whitespacesAndNewlines) }
        .onChange(of: input) { _, value in if value.isEmpty { query = "" } }
        .toolbar { GallerySortPicker(selection: $sort) }
    }
}
