import SwiftUI
import NHVCore

struct GalleryCollectionView: View {
    let api: NHentaiAPI
    let query: GalleryQuery
    @Environment(MediaStore.self) private var media
    @Environment(FavoriteStore.self) private var favorites

    var body: some View {
        GalleryFeedView(api: api, query: query, media: media, favorites: favorites)
            .id(query)
    }
}

private struct GalleryFeedView: View {
    let api: NHentaiAPI
    let media: MediaStore
    let favorites: FavoriteStore
    let query: GalleryQuery
    @State private var feed: GalleryFeed
    @State private var nextPageTask: Task<Void, Never>?
    @State private var favoriteRevision = 0

    init(api: NHentaiAPI, query: GalleryQuery, media: MediaStore, favorites: FavoriteStore) {
        self.api = api
        self.media = media
        self.favorites = favorites
        self.query = query
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

    var body: some View {
        ScrollView {
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
                            NavigationLink {
                                GalleryDetailView(api: api, id: gallery.id)
                            } label: {
                                GalleryCard(gallery: gallery, url: media.thumbnail(gallery.thumbnail))
                            }
                            .buttonStyle(.plain)
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
        .background(Color.black)
        .refreshable {
            await media.prepare(api: api)
            await feed.refresh()
        }
        .task {
            await media.prepare(api: api)
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
    @Environment(FavoriteStore.self) private var favorites

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GalleryCover(url: url)
                .frame(maxWidth: .infinity)
                .aspectRatio(0.70, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomTrailing) {
                    if gallery.numPages > 0 {
                        Text("\(gallery.numPages) pages")
                            .font(.caption2.monospacedDigit())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }
                }

            Text(verbatim: gallery.englishTitle)
                .font(.subheadline.weight(.medium))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Label((favorites.states[gallery.id]?.count ?? gallery.numFavorites).formatted(), systemImage: favorites.states[gallery.id]?.favorited == true ? "heart.fill" : "heart")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
    }
}
