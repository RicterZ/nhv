import SwiftUI
import NHVCore

struct GalleryCollectionView<Header: View>: View {
    let api: NHentaiAPI
    let query: GalleryQuery
    var preloadedFavorites: FavoritesFeedStore? = nil
    @ViewBuilder var header: () -> Header
    @Environment(MediaStore.self) private var media
    @Environment(FavoriteStore.self) private var favorites
    @Environment(GalleryLanguageStore.self) private var languages

    var body: some View {
        GalleryFeedView(api: api, query: query, media: media, favorites: favorites, preloadedFavorites: preloadedFavorites, header: header)
            .id(query)
            .task { await languages.prepare(api: api) }
    }
}

extension GalleryCollectionView where Header == EmptyView {
    init(api: NHentaiAPI, query: GalleryQuery, preloadedFavorites: FavoritesFeedStore? = nil) {
        self.init(api: api, query: query, preloadedFavorites: preloadedFavorites, header: { EmptyView() })
    }
}

private struct GalleryFeedView<Header: View>: View {
    let api: NHentaiAPI
    let media: MediaStore
    let favorites: FavoriteStore
    let query: GalleryQuery
    let header: () -> Header
    let preloadedFavorites: FavoritesFeedStore?
    @State private var feed: GalleryFeed
    @State private var nextPageTask: Task<Void, Never>?
    @State private var favoriteRevision = 0
    @State private var isRefreshing = false

    init(api: NHentaiAPI, query: GalleryQuery, media: MediaStore, favorites: FavoriteStore,
         preloadedFavorites: FavoritesFeedStore? = nil, @ViewBuilder header: @escaping () -> Header) {
        self.api = api
        self.media = media
        self.favorites = favorites
        self.query = query
        self.header = header
        self.preloadedFavorites = preloadedFavorites
        _feed = State(initialValue: preloadedFavorites?.feed ?? GalleryFeed(
            load: { page in try await api.galleries(matching: query, page: page) },
            willPublish: { items in
                media.thumbnails.enqueue(items.compactMap { media.thumbnail($0.thumbnail, galleryID: $0.id) })
                if case .favorites = query {
                    for item in items { favorites.rememberFromFavoritesList(id: item.id, count: item.numFavorites) }
                }
            }
        ))
    }

    private var showsFavoriteCount: Bool {
        if case .favorites = query { return false }
        return true
    }

    private var prefersResultFavoriteCount: Bool {
        if case .search = query { return true }
        return false
    }

    private var displayedItems: [GallerySummary] {
        if case .favorites = query { return favorites.visibleFavorites(in: feed.items) }
        return feed.items
    }

    var body: some View {
        GalleryScrollView(header: header) {
            LazyVStack(spacing: 24) {
                if let error = media.error {
                    InlineErrorView(error: error)
                    Button("Try Again") {
                        Task {
                            await media.prepare(api: api)
                            media.thumbnails.enqueue(feed.items.compactMap { media.thumbnail($0.thumbnail, galleryID: $0.id) })
                        }
                    }
                }

                if !displayedItems.isEmpty {
                    GalleryGrid(galleries: displayedItems, api: api, showsFavoriteCount: showsFavoriteCount,
                        prefersResultFavoriteCount: prefersResultFavoriteCount, respectsNSFWSetting: true)
                }

                if let error = feed.error {
                    InlineErrorView(error: error)
                    Button("Try Again") {
                        Task { await feed.retry() }
                    }
                } else if feed.isLoading {
                    ProgressView("Loading galleries…")
                        .padding(24)
                } else if feed.hasLoaded && displayedItems.isEmpty && !feed.hasMore {
                    ContentUnavailableView("No galleries", systemImage: "books.vertical", description: Text("Pull down to refresh."))
                } else if feed.hasMore && feed.hasLoaded {
                    Button("Load More", action: loadMore)
                        .onAppear(perform: loadMore)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .scrollBounceBehavior(.always)
        .refreshable {
            guard !isRefreshing else { return }
            isRefreshing = true
            defer { isRefreshing = false }
            nextPageTask?.cancel()
            if let preloadedFavorites { await preloadedFavorites.refresh() }
            else { await feed.refresh() }
            if case .favorites = query {
                favorites.requestSynchronization(api: api)
            }
        }
        .task {
            if let preloadedFavorites {
                await preloadedFavorites.prepare()
                return
            }
            await media.prepare(api: api)
            media.thumbnails.enqueue(feed.items.compactMap { media.thumbnail($0.thumbnail, galleryID: $0.id) })
            if case .favorites = query, favoriteRevision != favorites.revision {
                await feed.refresh()
            } else {
                await feed.loadIfNeeded()
            }
            favoriteRevision = favorites.revision
        }
        .onDisappear {
            nextPageTask?.cancel()
            if preloadedFavorites == nil { feed.cancel() }
        }
    }

    private func loadMore() {
        guard !isRefreshing, !feed.isLoading else { return }
        nextPageTask = Task { await feed.loadNext() }
    }
}

struct GalleryGrid: View {
    let galleries: [GallerySummary]
    let api: NHentaiAPI
    let showsFavoriteCount: Bool
    var recordsBrowsingHistory = true
    var prefersResultFavoriteCount = false
    var respectsNSFWSetting = false
    @Environment(AppNavigation.self) private var navigation
    @Environment(MediaStore.self) private var media
    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 14, alignment: .top)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(galleries) { gallery in
                GalleryCard(gallery: gallery, url: media.thumbnail(gallery.thumbnail, galleryID: gallery.id), api: api,
                    showsFavoriteCount: showsFavoriteCount, recordsBrowsingHistory: recordsBrowsingHistory,
                    prefersResultFavoriteCount: prefersResultFavoriteCount, respectsNSFWSetting: respectsNSFWSetting,
                    openDetail: { navigation.openGallery(gallery, recordsVisit: recordsBrowsingHistory) })
            }
        }
    }
}

private struct GalleryCard: View {
    let gallery: GallerySummary
    let url: URL?
    let api: NHentaiAPI
    let showsFavoriteCount: Bool
    let recordsBrowsingHistory: Bool
    let prefersResultFavoriteCount: Bool
    let respectsNSFWSetting: Bool
    let openDetail: () -> Void
    @AppStorage(ContentDisplayPreference.nsfwKey) private var nsfwEnabled = true
    @Environment(CoverPreview.self) private var preview

    private var hidesCover: Bool { respectsNSFWSetting && !nsfwEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if hidesCover {
                    cover
                        .blur(radius: 8, opaque: true)
                        .overlay(.ultraThinMaterial.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            CoverHoldGesture(open: openDetail, preview: { shows in
                                if shows {
                                    preview.show(.init(id: gallery.id, url: url, title: gallery.englishTitle))
                                } else { preview.dismiss(id: gallery.id) }
                            })
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: gallery.englishTitle))
                        .accessibilityHint(Text("Hold to preview cover"))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { openDetail() }
                } else {
                    Button(action: openDetail) { cover }
                }
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                GalleryCardFavoriteButton(gallery: gallery, api: api, showsCount: showsFavoriteCount,
                    prefersResultCount: prefersResultFavoriteCount)
                    .padding(6)
            }
            .overlay(alignment: .bottomTrailing) {
                if gallery.numPages > 0 {
                    Text("\(gallery.numPages) pages")
                        .foregroundStyle(.white)
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                        .allowsHitTesting(false)
                }
            }

            Button(action: openDetail) {
                GalleryTitleLabel(title: gallery.englishTitle, tagIDs: gallery.tagIds)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.primary)
        .onDisappear { preview.dismiss(id: gallery.id) }
    }

    private var cover: some View {
        GalleryCover(url: url, fillsStandardCoverWidth: true)
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
