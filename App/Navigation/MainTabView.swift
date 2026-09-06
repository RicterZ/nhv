import SwiftUI
import NHVCore

struct MainTabView: View {
    let account: AuthenticatedSession
    @State private var media = MediaStore()
    @State private var favorites = FavoriteStore()

    var body: some View {
        TabView {
            NavigationStack { HomeView(api: account.api) }
                .tabItem { Label("Home", systemImage: "books.vertical") }
            NavigationStack { SearchView(api: account.api) }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            NavigationStack { FavoritesView(api: account.api) }
                .tabItem { Label("Favorites", systemImage: "heart") }
            NavigationStack { ProfileView(user: account.user) }
                .tabItem { Label("Me", systemImage: "person.crop.circle") }
        }
        .environment(media)
        .environment(favorites)
        .tint(Color(red: 237 / 255, green: 39 / 255, blue: 84 / 255))
        .preferredColorScheme(.dark)
        .onDisappear { media.thumbnails.cancel() }
    }
}
