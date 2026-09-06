import SwiftUI
import NHVCore

struct MainTabView: View {
    let account: AuthenticatedSession
    var isReady = true
    @Environment(LanguagePreference.self) private var language
    @State private var media: MediaStore
    @State private var favorites: FavoriteStore
    @State private var favoritesFeed: FavoritesFeedStore
    @State private var languages = GalleryLanguageStore()
    @State private var navigation = AppNavigation()
    @State private var coverPreview = CoverPreview()
    @AppStorage(ContentDisplayPreference.nsfwKey) private var nsfwEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark
    @AppStorage(ClipboardGallery.enabledKey) private var readsClipboard = true

    init(account: AuthenticatedSession, isReady: Bool = true) {
        self.account = account
        self.isReady = isReady
        let media = MediaStore()
        let favorites = FavoriteStore()
        _media = State(initialValue: media)
        _favorites = State(initialValue: favorites)
        _favoritesFeed = State(initialValue: FavoritesFeedStore(api: account.api, media: media, favorites: favorites))
    }

    private var canReadClipboard: Bool {
        isReady && scenePhase == .active && readsClipboard && !navigation.isReading
    }

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            NavigationStack(path: $navigation.homePath) {
                HomeView(api: account.api)
                    .navigationDestination(for: Int.self) { id in
                        GalleryDetailView(api: account.api, id: id)
                    }
            }
                .tabItem { Label(AppLocalization.string("Home", locale: language.locale), systemImage: "books.vertical") }
                .tag(AppNavigation.Tab.home)
            NavigationStack { SearchView(api: account.api, initialQuery: navigation.searchRequest.query) }
                .id(navigation.searchRequest.id)
                .tabItem { Label(AppLocalization.string("Search", locale: language.locale), systemImage: "magnifyingglass") }
                .tag(AppNavigation.Tab.search)
            NavigationStack { FavoritesView(api: account.api, preloaded: favoritesFeed) }
                .tabItem { Label(AppLocalization.string("Favorites", locale: language.locale), systemImage: "heart") }
                .tag(AppNavigation.Tab.favorites)
            NavigationStack { ProfileView(user: account.user, api: account.api) }
                .tabItem { Label(AppLocalization.string("Settings", locale: language.locale), systemImage: "gearshape") }
                .tag(AppNavigation.Tab.settings)
        }
        .overlay {
            if let item = coverPreview.item, !nsfwEnabled {
                CoverPreviewOverlay(item: item)
                    .id(item.id)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.16), value: coverPreview.item?.id)
        .onChange(of: nsfwEnabled) { _, _ in coverPreview.item = nil }
        .onChange(of: navigation.selectedTab) { _, _ in coverPreview.item = nil }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { coverPreview.item = nil }
        }
        .environment(coverPreview)
        .environment(navigation)
        .environment(media)
        .environment(favorites)
        .environment(languages)
        .tint(theme.accentColor)
        .preferredColorScheme(theme.colorScheme)
        .task { await favoritesFeed.prepare() }
        .onDisappear {
            favoritesFeed.cancel()
            media.thumbnails.cancel()
        }
        .task(id: canReadClipboard) {
            guard canReadClipboard else { return }
            if let link = ClipboardGallery.nextGallery() {
                coverPreview.item = nil
                navigation.openGallery(id: link.galleryID)
                ClipboardGallery.clearAfterOpening(link)
            }
        }
    }
}
