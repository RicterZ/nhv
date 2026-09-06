import NHVCore

/// Account-scoped list shared by startup preloading and the Favorites tab.
@MainActor
final class FavoritesFeedStore {
    let feed: GalleryFeed
    private let favorites: FavoriteStore
    private let media: MediaStore
    private let api: NHentaiAPI
    private var revision = 0
    private var request: Task<Void, Never>?

    init(api: NHentaiAPI, media: MediaStore, favorites: FavoriteStore) {
        self.api = api
        self.media = media
        self.favorites = favorites
        feed = GalleryFeed(load: { page in try await api.favorites(page: page) }, willPublish: { items in
            media.thumbnails.enqueue(items.compactMap { media.thumbnail($0.thumbnail, galleryID: $0.id) })
            for item in items { favorites.rememberFromFavoritesList(id: item.id, count: item.numFavorites) }
        })
    }

    func prepare() async {
        if let request { await request.value; return }
        let task = Task {
            await media.prepare(api: api)
            let requestedRevision = favorites.revision
            if requestedRevision != revision {
                await feed.refresh()
            } else {
                await feed.loadIfNeeded()
            }
            if feed.hasLoaded, feed.error == nil { revision = requestedRevision }
            media.thumbnails.enqueue(feed.items.compactMap { media.thumbnail($0.thumbnail, galleryID: $0.id) })
        }
        request = task
        await task.value
        request = nil
    }

    func cancel() {
        request?.cancel()
        request = nil
        feed.cancel()
    }
}
