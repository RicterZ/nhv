import Foundation
import Testing
@testable import NHVCore

private func galleryPage(_ ids: [Int], pages: Int = 3) throws -> PaginatedResponse<GallerySummary> {
    let result = ids.map { id -> [String: Any] in
        ["id": id, "media_id": String(id), "english_title": "Fixture \(id)",
         "thumbnail": "/galleries/\(id)/thumb.webp", "thumbnail_width": 200, "thumbnail_height": 300]
    }
    let data = try JSONSerialization.data(withJSONObject: ["result": result, "num_pages": pages])
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(PaginatedResponse<GallerySummary>.self, from: data)
}

@Test @MainActor func feedPreservesServerOrderAndDoesNotLimitResults() async throws {
    var published: [Int] = []
    let feed = GalleryFeed(load: { _ in try galleryPage(Array((1...37).reversed()), pages: 1) }, willPublish: {
        published = $0.map(\.id)
    })
    await feed.loadIfNeeded()
    #expect(feed.items.map(\.id) == Array((1...37).reversed()))
    #expect(published == feed.items.map(\.id))
    #expect(!feed.hasMore)
}

@Test @MainActor func paginationDeduplicatesAndStopsAtLastPage() async throws {
    let feed = GalleryFeed { page in
        try galleryPage(page == 1 ? [3, 2, 1] : [1, 4, 5], pages: 2)
    }
    await feed.loadNext()
    await feed.loadNext()
    await feed.loadNext()
    #expect(feed.items.map(\.id) == [3, 2, 1, 4, 5])
    #expect(!feed.hasMore)
}

private actor ControlledPages {
    private var continuations: [Int: CheckedContinuation<PaginatedResponse<GallerySummary>, any Error>] = [:]
    private var calls = 0
    private var observer: CheckedContinuation<Void, Never>?
    private var expectedCount = 0

    func load(_ page: Int) async throws -> PaginatedResponse<GallerySummary> {
        let call = calls
        calls += 1
        return try await withCheckedThrowingContinuation { continuation in
            continuations[call] = continuation
            if calls >= expectedCount { observer?.resume(); observer = nil }
        }
    }

    func waitForCalls(_ count: Int) async {
        if calls >= count { return }
        expectedCount = count
        await withCheckedContinuation { observer = $0 }
    }

    func resolve(_ call: Int, ids: [Int]) throws {
        continuations.removeValue(forKey: call)?.resume(returning: try galleryPage(ids))
    }

    func reject(_ call: Int) {
        continuations.removeValue(forKey: call)?.resume(throwing: APIError.transport)
    }

    func count() -> Int { calls }
}

@Test @MainActor func refreshDiscardsOlderPageResponse() async throws {
    let source = ControlledPages()
    let feed = GalleryFeed { try await source.load($0) }
    let first = Task { await feed.loadNext() }
    await source.waitForCalls(1)
    let refresh = Task { await feed.refresh() }
    await source.waitForCalls(2)
    try await source.resolve(1, ids: [90, 80])
    await refresh.value
    try await source.resolve(0, ids: [1, 2])
    await first.value
    #expect(feed.items.map(\.id) == [90, 80])
    #expect(!feed.isLoading)
}

@Test @MainActor func repeatedLoadMoreDoesNotDuplicateRequest() async throws {
    let source = ControlledPages()
    let feed = GalleryFeed { try await source.load($0) }
    let first = Task { await feed.loadNext() }
    await source.waitForCalls(1)
    await feed.loadNext()
    #expect(await source.count() == 1)
    try await source.resolve(0, ids: [1])
    await first.value
}

@Test @MainActor func cancelPreventsLatePagePublication() async throws {
    let source = ControlledPages()
    let feed = GalleryFeed { try await source.load($0) }
    let request = Task { await feed.loadNext() }
    await source.waitForCalls(1)
    feed.cancel()
    try await source.resolve(0, ids: [1])
    await request.value
    #expect(feed.items.isEmpty)
    #expect(!feed.isLoading)
}

@Test @MainActor func failedRefreshRetainsItemsAndRetriesFirstPage() async throws {
    let source = ControlledPages()
    let feed = GalleryFeed { try await source.load($0) }
    let request = Task { await feed.loadNext() }
    await source.waitForCalls(1)
    try await source.resolve(0, ids: [1, 2])
    await request.value
    let refresh = Task { await feed.refresh() }
    await source.waitForCalls(2)
    await source.reject(1)
    await refresh.value
    #expect(feed.items.map(\.id) == [1, 2])
    let retry = Task { await feed.retry() }
    await source.waitForCalls(3)
    try await source.resolve(2, ids: [9])
    await retry.value
    #expect(feed.items.map(\.id) == [9])
    #expect(feed.error == nil)
}

@Test @MainActor func rateLimitPreventsImmediateRetry() async throws {
    let transport = StubTransport("{}", status: 429, headers: ["Retry-After": "30"])
    let api = try makeAPI(transport)
    let feed = GalleryFeed { try await api.galleries(page: $0) }
    await feed.loadNext()
    await feed.retry()
    #expect(await transport.captured().count == 1)
    #expect(feed.retryDate != nil)
}

@Test func orderedQueueStartsInOrderAndHonorsConcurrency() {
    var queue = OrderedWorkQueue<Int>(concurrency: 4)
    queue.enqueue([9, 8, 7, 6, 5, 4])
    queue.enqueue([9, 7, 5, 3])
    #expect((0..<4).compactMap { _ in queue.next() } == [9, 8, 7, 6])
    #expect(queue.next() == nil)
    queue.finish(7)
    #expect(queue.next() == 5)
    queue.finish(9)
    #expect(queue.next() == 4)
    queue.finish(8)
    #expect(queue.next() == 3)
    #expect(queue.next() == nil)
    queue.removeAll()
    queue.enqueue([9])
    #expect(queue.next() == 9)
}

@Test func firstSixCoversFinishBeforeLaterCoversStart() {
    var queue = OrderedWorkQueue<Int>(concurrency: 6, batchSize: 6)
    queue.enqueue(Array(1...15))
    #expect((0..<6).compactMap { _ in queue.next() } == Array(1...6))
    // A fast lower cover must not start the next batch while the top one is slow.
    for id in [6, 4, 2, 5, 3] {
        queue.finish(id)
        #expect(queue.next() == nil)
    }
    queue.enqueue([7, 8, 16]) // View appearances do not bypass the barrier.
    queue.finish(1)
    #expect((0..<6).compactMap { _ in queue.next() } == Array(7...12))
    #expect(queue.next() == nil)
    for id in 7...12 { queue.finish(id) }
    #expect((0..<6).compactMap { _ in queue.next() } == Array(13...16))
    queue.removeAll()
    queue.enqueue([20, 21])
    #expect(queue.next() == 20)
    #expect(queue.next() == 21)
}

@Test(arguments: [GalleryQuery.latest, .favorites("abc"), .search("abc", .week)])
func collectionQueriesUseServerDefaultPageSize(query: GalleryQuery) async throws {
    let transport = StubTransport(emptyPage)
    _ = try await makeAPI(transport).galleries(matching: query, page: 2)
    let request = try #require(await transport.captured().first)
    let params = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
    #expect(params.first(where: { $0.name == "page" })?.value == "2")
    #expect(!params.contains(where: { $0.name == "per_page" }))
    let path: String = switch query {
    case .latest: "/api/v2/galleries"
    case .favorites: "/api/v2/favorites"
    case .search: "/api/v2/search"
    }
    #expect(request.url?.path == path)
}
