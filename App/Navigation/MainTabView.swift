import SwiftUI
import NHVCore

struct MainTabView: View {
    let account: AuthenticatedSession
    @Environment(LanguagePreference.self) private var language
    @State private var media = MediaStore()
    @State private var favorites = FavoriteStore()
    @State private var languages = GalleryLanguageStore()
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark

    var body: some View {
        TabView {
            NavigationStack { HomeView(api: account.api) }
                .tabItem { Label(AppLocalization.string("Home", locale: language.locale), systemImage: "books.vertical") }
            NavigationStack { SearchView(api: account.api) }
                .tabItem { Label(AppLocalization.string("Search", locale: language.locale), systemImage: "magnifyingglass") }
            NavigationStack { FavoritesView(api: account.api) }
                .tabItem { Label(AppLocalization.string("Favorites", locale: language.locale), systemImage: "heart") }
            NavigationStack { ProfileView(user: account.user) }
                .tabItem { Label(AppLocalization.string("Settings", locale: language.locale), systemImage: "gearshape") }
        }
        .environment(media)
        .environment(favorites)
        .environment(languages)
        .tint(theme.accentColor)
        .preferredColorScheme(theme.colorScheme)
        .onDisappear { media.thumbnails.cancel() }
    }
}
