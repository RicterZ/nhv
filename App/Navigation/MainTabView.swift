import SwiftUI
import NHVCore

struct MainTabView: View {
    let account: AuthenticatedSession

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "books.vertical") }
            NavigationStack { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            NavigationStack { FavoritesView() }
                .tabItem { Label("Favorites", systemImage: "heart") }
            NavigationStack { ProfileView(user: account.user) }
                .tabItem { Label("Me", systemImage: "person.crop.circle") }
        }
    }
}
