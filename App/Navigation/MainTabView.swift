import SwiftUI
import NHVCore

struct MainTabView: View {
    let account: AuthenticatedSession
    @State private var media = MediaStore()
    @State private var favorites = FavoriteStore()
    @State private var languages = GalleryLanguageStore()
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark

    var body: some View {
        TabView {
            NavigationStack { HomeView(api: account.api) }
                .tabItem { Label("Home", systemImage: "books.vertical") }
            NavigationStack { SearchView(api: account.api) }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            NavigationStack { FavoritesView(api: account.api) }
                .tabItem { Label("Favorites", systemImage: "heart") }
            NavigationStack { ProfileView(user: account.user) }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environment(media)
        .environment(favorites)
        .environment(languages)
        .tint(theme.accentColor)
        .preferredColorScheme(theme.colorScheme)
        .onDisappear { media.thumbnails.cancel() }
    }
}
