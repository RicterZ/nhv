import Foundation
import Observation
import NHVCore

@MainActor @Observable
final class MediaStore {
    let thumbnails = ThumbnailStore()
    let reader = ReaderImageStore()
    private(set) var isClearingCache = false
    private(set) var resolver: CDNResolver?
    private(set) var error: (any Error)?
    @ObservationIgnored private var request: Task<CDNConfiguration, any Error>?
    @ObservationIgnored private var repairs: [Int: Task<(GalleryDetail, CDNResolver), any Error>] = [:]
    @ObservationIgnored private var recentRepairs: [Int: (Date, GalleryDetail, CDNResolver)] = [:]

    init() {
        if let data = UserDefaults.standard.data(forKey: "media.cdnConfiguration"),
           let config = try? JSONDecoder().decode(CDNConfiguration.self, from: data) {
            resolver = CDNResolver(configuration: config)
        }
    }

    func prepare(api: NHentaiAPI) async {
        thumbnails.recover = { [weak self] reference in
            guard let self else { throw CancellationError() }
            return try await self.repair(reference, api: api)
        }
        reader.recover = thumbnails.recover
        guard resolver == nil else { return }
        if request == nil { request = Task { try await api.cdnConfiguration() } }
        guard let request else { return }
        do {
            let config = try await request.value
            resolver = CDNResolver(configuration: config)
            if let data = try? JSONEncoder().encode(config) {
                UserDefaults.standard.set(data, forKey: "media.cdnConfiguration")
            }
            error = nil
        } catch { self.error = error }
        self.request = nil
    }

    func thumbnail(_ path: String, galleryID: Int, kind: GalleryImageReference.Kind = .thumbnail) -> URL? {
        guard let url = try? resolver?.url(for: path, kind: .thumbnail) else { return nil }
        thumbnails.references[url] = GalleryImageReference(galleryID: galleryID, kind: kind)
        return url
    }

    func image(_ path: String, galleryID: Int, page: Int) -> URL? {
        guard let url = try? resolver?.url(for: path, kind: .image) else { return nil }
        reader.references[url] = GalleryImageReference(galleryID: galleryID, kind: .page(page))
        return url
    }

    private func repair(_ reference: GalleryImageReference, api: NHentaiAPI) async throws -> URL {
        let id = reference.galleryID
        if let (date, gallery, resolver) = recentRepairs[id], Date().timeIntervalSince(date) < 60 {
            return try repairedURL(reference, gallery: gallery, resolver: resolver)
        }
        let task: Task<(GalleryDetail, CDNResolver), any Error>
        let ownsTask = repairs[id] == nil
        if let existing = repairs[id] { task = existing }
        else {
            task = Task {
                async let detail = GalleryDetailCache.shared.gallery(id: id, api: api, refresh: true)
                async let configuration = api.cdnConfiguration()
                let (gallery, config) = try await (detail, configuration)
                if let data = try? JSONEncoder().encode(config) {
                    UserDefaults.standard.set(data, forKey: "media.cdnConfiguration")
                }
                return (gallery, CDNResolver(configuration: config))
            }
            repairs[id] = task
        }
        defer { if ownsTask { repairs[id] = nil } }
        let (gallery, refreshedResolver) = try await task.value
        recentRepairs[id] = (Date(), gallery, refreshedResolver)
        return try repairedURL(reference, gallery: gallery, resolver: refreshedResolver)
    }

    private func repairedURL(_ reference: GalleryImageReference, gallery: GalleryDetail, resolver: CDNResolver) throws -> URL {
        guard let path = reference.path(in: gallery) else { throw APIError.notFound }
        // Keep current on-screen URL identities stable; new sessions use the
        // saved CDN configuration. The retried image fills the existing slot.
        let kind: CDNResolver.MediaKind
        if case .page = reference.kind { kind = .image } else { kind = .thumbnail }
        return try resolver.url(for: path, kind: kind)
    }

    func imageCacheSize() async throws -> Int64 {
        async let thumbnailSize = thumbnails.diskCacheSize()
        async let readerSize = reader.diskCacheSize()
        async let detailSize = GalleryDetailCache.shared.sizeInBytes()
        return try await thumbnailSize + readerSize + detailSize
    }

    func clearImageCache() async throws {
        guard !isClearingCache else { return }
        isClearingCache = true
        defer { isClearingCache = false }
        let pendingRepairs = Array(repairs.values)
        pendingRepairs.forEach { $0.cancel() }
        for repair in pendingRepairs { _ = try? await repair.value }
        repairs.removeAll()
        recentRepairs.removeAll()
        async let thumbnailClear: Void = thumbnails.clearCache()
        async let readerClear: Void = reader.clearCache()
        async let detailClear: Void = GalleryDetailCache.shared.clear()
        _ = try await (thumbnailClear, readerClear, detailClear)
    }
}
