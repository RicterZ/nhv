import Foundation
import Testing
@testable import NHVCore

private let detailJSON = #"{"id":1,"media_id":"2","title":{"english":"Fixture","pretty":"Fixture"},"cover":{"path":"/cover.webp","width":20,"height":30},"thumbnail":{"path":"/thumb.webp","width":2,"height":3},"upload_date":123,"tags":[],"num_pages":1,"num_favorites":5,"is_favorited":true,"pages":[{"number":1,"path":"/1.webp","width":20,"height":30,"thumbnail":"/1t.webp","thumbnail_width":2,"thumbnail_height":3}]}"#

@Test func detailCacheSurvivesRestartWithoutNetworkAndDoesNotPersistFavoriteStatus() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let transport = StubTransport(detailJSON)
    let cache = GalleryDetailCache(directory: directory)
    _ = try await cache.gallery(id: 1, api: makeAPI(transport))
    let offline = StubTransport("", status: 503)
    let result = try await GalleryDetailCache(directory: directory).gallery(id: 1, api: makeAPI(offline))
    #expect(result.title.english == "Fixture")
    #expect(result.pages.first?.path == "/1.webp")
    #expect(result.isFavorited == nil)
    #expect(await offline.captured().isEmpty)
    #expect(try await cache.sizeInBytes() > 0)
    #expect(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
}

@Test func detailCacheRefreshClearAndCorruption() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let transport = StubTransport(detailJSON)
    let api = try makeAPI(transport)
    let cache = GalleryDetailCache(directory: directory)
    _ = try await cache.gallery(id: 1, api: api)
    _ = try await cache.gallery(id: 1, api: api, refresh: true)
    #expect(await transport.captured().count == 2)
    try Data("broken".utf8).write(to: directory.appendingPathComponent("1.json"))
    _ = try await cache.gallery(id: 1, api: api)
    #expect(await transport.captured().count == 3)
    try await cache.clear()
    #expect(try await cache.sizeInBytes() == 0)
    _ = try await cache.gallery(id: 1, api: api)
    #expect(await transport.captured().count == 4)
    let offline = try makeAPI(StubTransport("", status: 503))
    await #expect(throws: (any Error).self) { _ = try await cache.gallery(id: 1, api: offline, refresh: true) }
    #expect(try await cache.gallery(id: 1, api: offline).id == 1)
}

@Test func refreshedFavoriteCountReplacesPersistedMetadata() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = GalleryDetailCache(directory: directory)
    let zero = detailJSON.replacingOccurrences(of: "\"num_favorites\":5", with: "\"num_favorites\":0")
    _ = try await cache.gallery(id: 1, api: makeAPI(StubTransport(zero)))
    let refreshed = try await cache.gallery(id: 1, api: makeAPI(StubTransport(detailJSON)), refresh: true)
    #expect(refreshed.numFavorites == 5)
    let offline = StubTransport("", status: 503)
    let reopened = try await GalleryDetailCache(directory: directory).gallery(id: 1, api: makeAPI(offline))
    #expect(reopened.numFavorites == 5)
    #expect(reopened.isFavorited == nil)
    #expect(await offline.captured().isEmpty)
}

@Test func imageKeysSeparateGalleryAndImageRoles() async throws {
    let references = [
        GalleryImageReference(galleryID: 1, kind: .cover),
        GalleryImageReference(galleryID: 1, kind: .thumbnail),
        GalleryImageReference(galleryID: 1, kind: .page(1)),
        GalleryImageReference(galleryID: 1, kind: .pageThumbnail(1)),
        GalleryImageReference(galleryID: 1, kind: .page(2)),
        GalleryImageReference(galleryID: 2, kind: .cover)
    ]
    #expect(Set(references.map(\.cacheKey)).count == references.count)
    let detail = try await makeAPI(StubTransport(detailJSON)).gallery(id: 1)
    #expect(references[0].path(in: detail) == "/cover.webp")
    #expect(references[2].path(in: detail) == "/1.webp")
    #expect(references[3].path(in: detail) == "/1t.webp")
    #expect(references[4].path(in: detail) == nil)
    #expect(references[5].path(in: detail) == nil)
}
