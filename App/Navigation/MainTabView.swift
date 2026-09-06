import SwiftUI
import NHVCore

struct MainTabView: View {
    let account: AuthenticatedSession
    @Environment(LanguagePreference.self) private var language
    @State private var media = MediaStore()
    @State private var favorites = FavoriteStore()
    @State private var languages = GalleryLanguageStore()
    @State private var navigation = AppNavigation()
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            NavigationStack { HomeView(api: account.api) }
                .tabItem { Label(AppLocalization.string("Home", locale: language.locale), systemImage: "books.vertical") }
                .tag(AppNavigation.Tab.home)
            NavigationStack { SearchView(api: account.api, initialQuery: navigation.searchRequest.query) }
                .id(navigation.searchRequest.id)
                .tabItem { Label(AppLocalization.string("Search", locale: language.locale), systemImage: "magnifyingglass") }
                .tag(AppNavigation.Tab.search)
            NavigationStack { FavoritesView(api: account.api) }
                .tabItem { Label(AppLocalization.string("Favorites", locale: language.locale), systemImage: "heart") }
                .tag(AppNavigation.Tab.favorites)
            NavigationStack { ProfileView(user: account.user, api: account.api) }
                .tabItem { Label(AppLocalization.string("Settings", locale: language.locale), systemImage: "gearshape") }
                .tag(AppNavigation.Tab.settings)
        }
        .environment(navigation)
        .environment(media)
        .environment(favorites)
        .environment(languages)
        .tint(theme.accentColor)
        .preferredColorScheme(theme.colorScheme)
        .onDisappear { media.thumbnails.cancel() }
    }
}
