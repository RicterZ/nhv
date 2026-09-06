import SwiftUI
import NHVCore

struct GalleryCollectionView<Header: View>: View {
    let api: NHentaiAPI
    let query: GalleryQuery
    @ViewBuilder var header: () -> Header
    @Environment(MediaStore.self) private var media
    @Environment(FavoriteStore.self) private var favorites
    @Environment(GalleryLanguageStore.self) private var languages

    var body: some View {
        GalleryFeedView(api: api, query: query, media: media, favorites: favorites, header: header)
            .id(query)
            .task { await languages.prepare(api: api) }
    }
}

extension GalleryCollectionView where Header == EmptyView {
    init(api: NHentaiAPI, query: GalleryQuery) {
        self.init(api: api, query: query, header: { EmptyView() })
    }
}

private struct GalleryFeedView<Header: View>: View {
    let api: NHentaiAPI
    let media: MediaStore
    let favorites: FavoriteStore
    let query: GalleryQuery
    let header: () -> Header
    @State private var feed: GalleryFeed
    @State private var nextPageTask: Task<Void, Never>?
    @State private var favoriteRevision = 0

    init(api: NHentaiAPI, query: GalleryQuery, media: MediaStore, favorites: FavoriteStore, @ViewBuilder header: @escaping () -> Header) {
        self.api = api
        self.media = media
        self.favorites = favorites
        self.query = query
        self.header = header
        _feed = State(initialValue: GalleryFeed(
            load: { page in try await api.galleries(matching: query, page: page) },
            willPublish: { items in
                media.thumbnails.enqueue(items.compactMap { media.thumbnail($0.thumbnail) })
                if case .favorites = query {
                    for item in items { favorites.remember(id: item.id, favorited: true, count: item.numFavorites) }
                }
            }
        ))
    }

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 14, alignment: .top)]

    private var showsFavoriteCount: Bool {
        if case .favorites = query { return false }
        return true
    }

    var body: some View {
        GalleryScrollView(header: header) {
            LazyVStack(spacing: 24) {
                if let error = media.error {
                    InlineErrorView(error: error)
                    Button("Try Again") {
                        Task {
                            await media.prepare(api: api)
                            media.thumbnails.enqueue(feed.items.compactMap { media.thumbnail($0.thumbnail) })
                        }
                    }
                }

                if !feed.items.isEmpty {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(feed.items) { gallery in
                            GalleryCard(gallery: gallery, url: media.thumbnail(gallery.thumbnail), api: api, showsFavoriteCount: showsFavoriteCount)
                        }
                    }
                }

                if let error = feed.error {
                    InlineErrorView(error: error)
                    Button("Try Again") {
                        Task { await feed.retry() }
                    }
                } else if feed.isLoading {
                    ProgressView("Loading galleries…")
                        .padding(24)
                } else if feed.hasLoaded && feed.items.isEmpty {
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
        .refreshable {
            await media.prepare(api: api)
            await feed.refresh()
        }
        .task {
            await media.prepare(api: api)
            media.thumbnails.enqueue(feed.items.compactMap { media.thumbnail($0.thumbnail) })
            if case .favorites = query, favoriteRevision != favorites.revision {
                await feed.refresh()
            } else {
                await feed.loadIfNeeded()
            }
            favoriteRevision = favorites.revision
        }
        .onDisappear {
            nextPageTask?.cancel()
            feed.cancel()
        }
    }

    private func loadMore() {
        guard !feed.isLoading else { return }
        nextPageTask = Task { await feed.loadNext() }
    }
}

private struct GalleryCard: View {
    let gallery: GallerySummary
    let url: URL?
    let api: NHentaiAPI
    let showsFavoriteCount: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                GalleryDetailView(api: api, id: gallery.id)
            } label: {
                GalleryCover(url: url, fillsStandardCoverWidth: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 4) {
                    GalleryCardFavoriteButton(gallery: gallery, api: api, showsCount: showsFavoriteCount)
                    Spacer(minLength: 0)
                    if gallery.numPages > 0 {
                        Text("\(gallery.numPages) pages")
                            .foregroundStyle(.white)
                            .font(.caption2.monospacedDigit())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                            .allowsHitTesting(false)
                    }
                }
                .padding(6)
            }

            NavigationLink {
                GalleryDetailView(api: api, id: gallery.id)
            } label: {
                GalleryTitleLabel(title: gallery.englishTitle, tagIDs: gallery.tagIds)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.primary)
    }
}
