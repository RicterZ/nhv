import SwiftUI
import NHVCore

private struct NavigationRailLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var usesNavigationRailLayout: Bool {
        get { self[NavigationRailLayoutKey.self] }
        set { self[NavigationRailLayoutKey.self] = newValue }
    }
}

struct MainTabView: View {
    let account: AuthenticatedSession
    var isReady = true
    @Environment(LanguagePreference.self) private var language
    @State private var media: MediaStore
    @State private var favorites: FavoriteStore
    @State private var favoritesFeed: FavoritesFeedStore
    @State private var languages = GalleryLanguageStore()
    @State private var navigation: AppNavigation
    @State private var selectedTab: AppNavigation.Tab
    @State private var coverPreview = CoverPreview()
    @State private var tagTranslations = TagTranslationStore()
    @AppStorage(ContentDisplayPreference.nsfwKey) private var nsfwEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark
    @AppStorage(ClipboardGallery.enabledKey) private var readsClipboard = true

    init(account: AuthenticatedSession, isReady: Bool = true) {
        self.account = account
        self.isReady = isReady
        let navigation = AppNavigation(accountID: account.user.id)
        _navigation = State(initialValue: navigation)
        _selectedTab = State(initialValue: navigation.selectedTab)
        let media = MediaStore()
        let favorites = FavoriteStore(accountID: account.user.id)
        _media = State(initialValue: media)
        _favorites = State(initialValue: favorites)
        _favoritesFeed = State(initialValue: FavoritesFeedStore(api: account.api, media: media, favorites: favorites))
    }

    private var canReadClipboard: Bool {
        isReady && scenePhase == .active && readsClipboard && !navigation.isReading
    }

    private func usesNavigationRail(in size: CGSize) -> Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        horizontalSizeClass == .regular && size.width > size.height
        #endif
    }

    private var navigationRailWidth: CGFloat {
        66
    }

    private var navigationRailContentSpacing: CGFloat {
        6
    }

    private var selectedTabBackground: Color {
        selectedTab == .settings
            ? Color(uiColor: .systemGroupedBackground)
            : Color(uiColor: .systemBackground)
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if usesNavigationRail(in: geometry.size) {
                    navigationRailLayout
                } else {
                    tabs(selection: $selectedTab)
                }
            }
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
        .onChange(of: selectedTab) { _, newValue in
            navigation.selectedTab = newValue
            coverPreview.item = nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { coverPreview.item = nil }
        }
        .fullScreenCover(item: $navigation.reader) { destination in
            ReaderView(destination: destination, api: account.api)
                .environment(media)
                .environment(navigation)
        }
        .environment(coverPreview)
        .environment(navigation)
        .environment(media)
        .environment(favorites)
        .environment(languages)
        .environment(tagTranslations)
        .tint(theme.accentColor)
        .preferredColorScheme(theme.colorScheme)
        .task { await favoritesFeed.prepare() }
        .task(id: scenePhase) {
            if scenePhase == .active { await tagTranslations.prepare() }
        }
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

    private var navigationRailLayout: some View {
        ZStack(alignment: .leading) {
            selectedTabContent(selectedTab)
                .environment(\.usesNavigationRailLayout, true)
                .contentMargins(
                    .leading,
                    navigationRailWidth + 6 + navigationRailContentSpacing,
                    for: .scrollContent
                )
            navigationRail
        }
        .background(selectedTabBackground.ignoresSafeArea())
    }

    private var navigationRail: some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                railButton(.home, title: "Home", systemImage: "books.vertical")
                railButton(.search, title: "Search", systemImage: "magnifyingglass")
                railButton(.favorites, title: "Favorites", systemImage: "heart")
                railButton(.settings, title: "Settings", systemImage: "gearshape")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .frame(width: navigationRailWidth)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(NavigationRailGlass())
        .frame(width: navigationRailWidth + 6, alignment: .trailing)
        .zIndex(1)
    }

    @ViewBuilder
    private func selectedTabContent(_ tab: AppNavigation.Tab) -> some View {
        switch tab {
        case .home:
            stack(.home) { HomeView(api: account.api) }
        case .search:
            stack(.search) { SearchView(api: account.api, savedState: navigation.searchState("root")) }
        case .favorites:
            stack(.favorites) { FavoritesView(api: account.api, preloaded: favoritesFeed) }
        case .settings:
            stack(.settings) { ProfileView(user: account.user, api: account.api) }
        }
    }

    private func tabs(selection: Binding<AppNavigation.Tab>) -> some View {
        TabView(selection: selection) {
            stack(.home) { HomeView(api: account.api) }
                .tabItem { Label(AppLocalization.string("Home", locale: language.locale), systemImage: "books.vertical") }
                .tag(AppNavigation.Tab.home)
            stack(.search) { SearchView(api: account.api, savedState: navigation.searchState("root")) }
                .tabItem { Label(AppLocalization.string("Search", locale: language.locale), systemImage: "magnifyingglass") }
                .tag(AppNavigation.Tab.search)
            stack(.favorites) { FavoritesView(api: account.api, preloaded: favoritesFeed) }
                .tabItem { Label(AppLocalization.string("Favorites", locale: language.locale), systemImage: "heart") }
                .tag(AppNavigation.Tab.favorites)
            stack(.settings) { ProfileView(user: account.user, api: account.api) }
                .tabItem { Label(AppLocalization.string("Settings", locale: language.locale), systemImage: "gearshape") }
                .tag(AppNavigation.Tab.settings)
        }
    }

    private func railButton(
        _ tab: AppNavigation.Tab,
        title: String.LocalizationValue,
        systemImage: String
    ) -> some View {
        let selected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: selected ? .semibold : .regular))
                Text(verbatim: AppLocalization.string(title, locale: language.locale))
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(selected ? theme.accentColor : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .background(
                selected ? theme.accentColor.opacity(0.14) : Color.primary.opacity(0.001),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func stack<Content: View>(_ tab: AppNavigation.Tab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: Binding(get: { navigation.path(for: tab) }, set: { navigation.setPath($0, for: tab) })) {
            content().navigationDestination(for: AppNavigation.Route.self) { route in
                switch route.kind {
                case .gallery(let id):
                    if let summary = navigation.summaries[id] {
                        GalleryDetailView(api: account.api, summary: summary, recordsBrowsingHistory: route.recordsVisit)
                    } else {
                        GalleryDetailView(api: account.api, id: id, recordsBrowsingHistory: route.recordsVisit)
                    }
                case .search(let query):
                    SearchView(api: account.api, stateKey: route.id.uuidString,
                        savedState: navigation.searchState(route.id.uuidString, initialQuery: query))
                case .history: BrowsingHistoryView(api: account.api)
                }
            }
        }
    }

}

private struct NavigationRailGlass: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        }
    }
}
