import SwiftUI

struct FavoritesView: View {
    var body: some View {
        ContentUnavailableView("Favorites", systemImage: "heart", description: Text("Your saved galleries"))
            .navigationTitle("Favorites")
    }
}
