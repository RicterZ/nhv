import Foundation
import Testing
@testable import NHVCore

private actor FavoriteTransport: HTTPTransport {
    let pages: [[Int]]
    let failingPage: Int?
    let pausesLastPage: Bool
    private var requestedPages: [Int] = []
    private var paused: CheckedContinuation<Void, Never>?

    init(pages: [[Int]], failingPage: Int? = nil, pausesLastPage: Bool = false) {
        self.pages = pages
        self.failingPage = failingPage
        self.pausesLastPage = pausesLastPage
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        var body: [String: Any]
        var status = 200
        if url.lastPathComponent == "favorites" {
            let page = Int(URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
                .first { $0.name == "page" }!.value!)!
            requestedPages.append(page)
            if pausesLastPage, page == pages.count {
                await withCheckedContinuation { paused = $0 }
            }
            if page == failingPage { status = 503 }
            body = ["num_pages": pages.count, "result": pages[page - 1].map { id in
                ["id": id, "media_id": "2", "english_title": "Fixture",
                 "thumbnail": "/thumb.webp", "thumbnail_width": 2, "thumbnail_height": 3] as [String: Any]
            }]
        } else {
            body = ["favorited": request.httpMethod == "POST", "num_favorites": 8]
        }
        return (try JSONSerialization.data(withJSONObject: body),
                HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    func isPaused() -> Bool { paused != nil }
    func resume() { paused?.resume(); paused = nil }
    func requests() -> [Int] { requestedPages }
}

@MainActor private func favoriteDefaults() -> UserDefaults {
    UserDefaults(suiteName: "FavoriteStoreTests.\(UUID().uuidString)")!
}

@Test @MainActor func favoritesPersistAcrossRestartAndStayAccountScoped() async throws {
    let defaults = favoriteDefaults()
    let store = FavoriteStore(accountID: 1, defaults: defaults)
    let api = try makeAPI(FavoriteTransport(pages: [[]]))
    try await store.set(id: 42, favorited: true, api: api)
    #expect(FavoriteStore(accountID: 1, defaults: defaults).states[42]?.favorited == true)
    #expect(FavoriteStore(accountID: 2, defaults: defaults).states.isEmpty)
    try await store.set(id: 42, favorited: false, api: api)
    let reopened = FavoriteStore(accountID: 1, defaults: defaults)
    #expect(reopened.states[42]?.favorited == false)
    #expect(reopened.states[42]?.count == 8)
}

@Test @MainActor func favoriteSyncReadsEveryPageAndReconcilesRemovals() async throws {
    let defaults = favoriteDefaults()
    let store = FavoriteStore(accountID: 1, defaults: defaults)
    store.rememberFromFavoritesList(id: 99, count: 12)
    let transport = FavoriteTransport(pages: [[1], [42]])
    await store.synchronize(api: try makeAPI(transport))
    #expect(await transport.requests() == [1, 2])
    #expect(store.states[1]?.favorited == true)
    #expect(store.states[42]?.favorited == true)
    #expect(store.states[99]?.favorited == false)
    let reopened = FavoriteStore(accountID: 1, defaults: defaults)
    #expect(reopened.states == store.states)
    // Foreground events close together do not repeatedly scan the list.
    await store.synchronize(api: try makeAPI(transport))
    #expect(await transport.requests() == [1, 2])
    await store.synchronize(api: try makeAPI(FavoriteTransport(pages: [[]])), force: true)
    #expect(store.states.values.allSatisfy { !$0.favorited })
}

@Test @MainActor func failedFavoriteSyncPreservesPersistentSnapshot() async throws {
    let defaults = favoriteDefaults()
    let store = FavoriteStore(accountID: 1, defaults: defaults)
    store.rememberFromFavoritesList(id: 99, count: 12)
    let before = store.states
    await store.synchronize(api: try makeAPI(FavoriteTransport(pages: [[1], [42]], failingPage: 2)))
    #expect(store.syncError != nil)
    #expect(store.states == before)
    #expect(FavoriteStore(accountID: 1, defaults: defaults).states == before)
}

@Test @MainActor func favoriteSyncCannotOverwriteConcurrentWrites() async throws {
    let defaults = favoriteDefaults()
    let store = FavoriteStore(accountID: 1, defaults: defaults)
    store.rememberFromFavoritesList(id: 42, count: 12)
    let transport = FavoriteTransport(pages: [[1], [42]], pausesLastPage: true)
    let api = try makeAPI(transport)
    let sync = Task { await store.synchronize(api: api) }
    while !(await transport.isPaused()) { await Task.yield() }
    try await store.set(id: 42, favorited: false, api: api)
    try await store.set(id: 100, favorited: true, api: api)
    await transport.resume()
    await sync.value
    #expect(store.states[42]?.favorited == false)
    #expect(store.states[100]?.favorited == true)
    #expect(FavoriteStore(accountID: 1, defaults: defaults).states == store.states)
}

@Test @MainActor func cancelledFavoriteSyncDoesNotPublishPartialResults() async throws {
    let store = FavoriteStore(accountID: 1, defaults: favoriteDefaults())
    store.rememberFromFavoritesList(id: 99, count: 12)
    let before = store.states
    let transport = FavoriteTransport(pages: [[1], [42]], pausesLastPage: true)
    let api = try makeAPI(transport)
    let sync = Task { await store.synchronize(api: api) }
    while !(await transport.isPaused()) { await Task.yield() }
    sync.cancel()
    await transport.resume()
    await sync.value
    #expect(store.states == before)
}

@Test @MainActor func staleDetailsAndListsCannotResurrectCancelledFavorite() async throws {
    let store = FavoriteStore(accountID: 1, defaults: favoriteDefaults())
    store.rememberFromFavoritesList(id: 42, count: 12)
    let version = store.version(for: 42)
    try await store.set(id: 42, favorited: false, api: makeAPI(FavoriteTransport(pages: [[]])))
    store.remember(id: 42, favorited: true, count: 12, expectedVersion: version)
    store.rememberFromFavoritesList(id: 42, count: 12)
    #expect(store.states[42]?.favorited == false)
    #expect(store.states[42]?.count == 8)
}

@Test @MainActor func knownFavoriteStateStillRefreshesAndPersists() async throws {
    let defaults = favoriteDefaults()
    let store = FavoriteStore(accountID: 1, defaults: defaults)
    store.rememberFromFavoritesList(id: 42, count: 12)
    await store.refresh(id: 42, api: try makeAPI(StubTransport(#"{"favorited":false,"num_favorites":9}"#)))
    #expect(FavoriteStore(accountID: 1, defaults: defaults).states[42]?.favorited == false)
    await store.refresh(id: 42, api: try makeAPI(StubTransport("", status: 503)))
    #expect(store.states[42]?.favorited == false)
    #expect(store.states[42]?.count == 9)
    await #expect(throws: (any Error).self) {
        try await store.set(id: 42, favorited: true, api: makeAPI(StubTransport("", status: 503)))
    }
    #expect(store.states[42]?.favorited == false)
    #expect(store.updating.isEmpty)
}

@Test @MainActor func cancelledFavoriteDisappearsImmediatelyAndStaleRefreshCannotRestoreIt() async throws {
    let defaults = favoriteDefaults()
    let api = try makeAPI(FavoriteTransport(pages: [[42]]))
    let store = FavoriteStore(accountID: 1, defaults: defaults)
    let feed = GalleryFeed(load: { page in try await api.favorites(page: page) })
    await feed.loadIfNeeded()
    store.rememberFromFavoritesList(id: 42, count: 12)
    #expect(store.visibleFavorites(in: feed.items).count == 1)
    try await store.set(id: 42, favorited: false, api: api)
    #expect(store.visibleFavorites(in: feed.items).isEmpty)
    // The list still returns 42, but its individual GET confirms cancellation.
    await feed.refresh()
    await store.synchronize(api: api, force: true)
    #expect(feed.items.count == 1)
    #expect(store.visibleFavorites(in: feed.items).isEmpty)
    let restarted = FavoriteStore(accountID: 1, defaults: defaults)
    await restarted.synchronize(api: api, force: true)
    #expect(restarted.visibleFavorites(in: feed.items).isEmpty)
    // An explicit re-favorite immediately makes an existing list item visible.
    try await restarted.set(id: 42, favorited: true, api: api)
    #expect(restarted.visibleFavorites(in: feed.items).count == 1)
}

private actor ConflictingFavoriteTransport: HTTPTransport {
    let favorited: Bool?
    init(favorited: Bool?) { self.favorited = favorited }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let isList = request.url!.lastPathComponent == "favorites"
        let body = isList
            ? #"{"result":[{"id":42,"media_id":"2","english_title":"Fixture","thumbnail":"/thumb.webp","thumbnail_width":2,"thumbnail_height":3}],"num_pages":1}"#
            : "{\"favorited\":\(favorited == true),\"num_favorites\":10}"
        let status = !isList && favorited == nil ? 503 : 200
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

@Test @MainActor func conflictingListKeepsKnownStateOnVerificationFailureAndAllowsExternalChanges() async throws {
    let store = FavoriteStore(accountID: 1, defaults: favoriteDefaults())
    store.remember(id: 42, favorited: false, count: 9, expectedVersion: store.version(for: 42))
    await store.synchronize(api: try makeAPI(ConflictingFavoriteTransport(favorited: nil)), force: true)
    #expect(store.states[42]?.favorited == false)
    // A verified change made on another device must still replace the cache.
    await store.synchronize(api: try makeAPI(ConflictingFavoriteTransport(favorited: true)), force: true)
    #expect(store.states[42]?.favorited == true)
    #expect(store.states[42]?.count == 10)
}

@Test @MainActor func requestingBackgroundSyncDoesNotWaitForSlowPagination() async throws {
    let store = FavoriteStore(accountID: 1, defaults: favoriteDefaults())
    let transport = FavoriteTransport(pages: [[1], [42]], pausesLastPage: true)
    let api = try makeAPI(transport)
    store.requestSynchronization(api: api)
    // The caller has already returned while the second page stays suspended.
    while !(await transport.isPaused()) { await Task.yield() }
    #expect(store.states.isEmpty)
    await transport.resume()
    while store.states[42] == nil { await Task.yield() }
    #expect(store.states[42]?.favorited == true)
}
