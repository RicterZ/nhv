import SwiftUI
import NHVCore

struct FavoritesView: View {
    let api: NHentaiAPI
    let preloaded: FavoritesFeedStore
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        GalleryCollectionView(api: api, query: .favorites(navigation.favoritesQuery), preloadedFavorites: navigation.favoritesQuery.isEmpty ? preloaded : nil)
            .localizedNavigationTitle("Favorites")
            .searchable(text: $navigation.favoritesInput, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search favorites")
            .onSubmit(of: .search) { navigation.favoritesQuery = navigation.favoritesInput.trimmingCharacters(in: .whitespacesAndNewlines) }
            .onChange(of: navigation.favoritesInput) { _, value in if value.isEmpty { navigation.favoritesQuery = "" } }
    }
}
