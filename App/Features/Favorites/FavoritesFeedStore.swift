import Foundation
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
    private var generation = UUID()

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
        let operation = generation
        let task = Task {
            await media.prepare(api: api)
            guard !Task.isCancelled, operation == generation else { return }
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
        if operation == generation { request = nil }
    }

    func refresh() async {
        // A late startup preload must not replace this explicit refresh.
        cancel()
        let requestedRevision = favorites.revision
        await feed.refresh()
        if feed.error == nil { revision = requestedRevision }
    }

    func cancel() {
        generation = UUID()
        request?.cancel()
        request = nil
        feed.cancel()
    }
}
