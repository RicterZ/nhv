import SwiftUI
import NHVCore

struct FavoritesView: View {
    let api: NHentaiAPI
    let preloaded: FavoritesFeedStore
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.usesNavigationRailLayout) private var usesNavigationRailLayout

    private var searchFieldPlacement: SearchFieldPlacement {
        usesNavigationRailLayout ? .toolbar : .navigationBarDrawer(displayMode: .always)
    }

    var body: some View {
        @Bindable var navigation = navigation
        GalleryCollectionView(api: api, query: .favorites(navigation.favoritesQuery), preloadedFavorites: navigation.favoritesQuery.isEmpty ? preloaded : nil)
            .localizedNavigationTitle("Favorites")
            .navigationBarTitleDisplayMode(usesNavigationRailLayout ? .inline : .large)
            .searchable(text: $navigation.favoritesInput, placement: searchFieldPlacement, prompt: "Search")
            .background(SearchFieldAlignment().frame(width: 0, height: 0))
            .onSubmit(of: .search) { navigation.favoritesQuery = navigation.favoritesInput.trimmingCharacters(in: .whitespacesAndNewlines) }
            .onChange(of: navigation.favoritesInput) { _, value in if value.isEmpty { navigation.favoritesQuery = "" } }
    }
}
