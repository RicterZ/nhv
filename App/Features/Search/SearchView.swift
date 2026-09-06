import SwiftUI

struct SearchView: View {
    var body: some View {
        ContentUnavailableView("Search", systemImage: "magnifyingglass", description: Text("Find galleries by title, artist, or tag"))
            .navigationTitle("Search")
    }
}
