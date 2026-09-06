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

    func prepare(api: NHentaiAPI) async {
        guard resolver == nil else { return }
        if request == nil { request = Task { try await api.cdnConfiguration() } }
        guard let request else { return }
        do {
            resolver = CDNResolver(configuration: try await request.value)
            error = nil
        } catch { self.error = error }
        self.request = nil
    }

    func thumbnail(_ path: String) -> URL? {
        try? resolver?.url(for: path, kind: .thumbnail)
    }

    func image(_ path: String) -> URL? {
        try? resolver?.url(for: path, kind: .image)
    }

    func clearImageCache() async throws {
        guard !isClearingCache else { return }
        isClearingCache = true
        defer { isClearingCache = false }
        async let thumbnailClear: Void = thumbnails.clearCache()
        async let readerClear: Void = reader.clearCache()
        _ = try await (thumbnailClear, readerClear)
    }
}
