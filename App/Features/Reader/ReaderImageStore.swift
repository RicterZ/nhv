import Foundation
import NHVCore
import Observation
import UIKit

@MainActor @Observable
final class ReaderImageStore {
    private(set) var images: [URL: UIImage] = [:]
    @ObservationIgnored private var tasks: [URL: Task<Void, Never>] = [:]
    @ObservationIgnored private var wanted: Set<URL> = []
    @ObservationIgnored private let diskCache = ImageDiskCache(namespace: "pages")
    @ObservationIgnored private let session: URLSession
    private(set) var isClearingCache = false
    @ObservationIgnored var references: [URL: GalleryImageReference] = [:]
    @ObservationIgnored var recover: (@Sendable (GalleryImageReference) async throws -> URL)?

    init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.httpMaximumConnectionsPerHost = 3
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 45
        session = URLSession(configuration: configuration)
    }

    /// Load the visible page first, then neighbors for interactive paging.
    /// Continuous scrolling keeps decoded pages until scrolling settles so a
    /// page-boundary update cannot invalidate the live canvas mid-motion.
    func focus(on index: Int, urls: [URL?], retainsLoadedImages: Bool = false) {
        guard !isClearingCache, let window = ReaderImageWindow(index: index, urls: urls) else { return }
        wanted = window.retained
        for url in Array(tasks.keys) where !wanted.contains(url) {
            tasks.removeValue(forKey: url)?.cancel()
        }
        if !retainsLoadedImages { trim(around: index, urls: urls) }
        for url in window.requested where images[url] == nil && tasks[url] == nil {
            tasks[url] = Task { [weak self] in await self?.load(url) }
        }
    }

    func trim(around index: Int, urls: [URL?]) {
        guard let window = ReaderImageWindow(index: index, urls: urls) else { return }
        // Keep one previous decoded page for quick back navigation.
        guard images.keys.contains(where: { !window.retained.contains($0) }) else { return }
        images = images.filter { window.retained.contains($0.key) }
    }

    /// Stop background work without changing the displayed image or its zoom.
    func pause() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        wanted.removeAll()
    }

    func cancel() {
        pause()
        images.removeAll()
    }

    func diskCacheSize() async throws -> Int64 {
        try await diskCache.sizeInBytes()
    }

    func clearCache() async throws {
        guard !isClearingCache else { return }
        isClearingCache = true
        defer { isClearingCache = false }
        let pending = Array(tasks.values)
        cancel()
        for task in pending { await task.value }
        try await diskCache.clear()
    }

    private func load(_ url: URL) async {
        var failures = 0
        while !Task.isCancelled && wanted.contains(url) {
            var delay = min(30.0, pow(2, Double(min(failures, 5))))
            do {
                let reference = references[url]
                let image = try await diskCache.image(for: url, reference: reference,
                    session: session, maximumPixelSize: 4096, recover: recover)
                try Task.checkCancellation()
                guard wanted.contains(url) else { return }
                images[url] = image
                tasks[url] = nil
                return
            } catch {
                if Task.isCancelled { return }
                // A second 404 is terminal for this focus; avoid an endless
                // metadata-refresh loop for a removed gallery or image.
                if case .server(status: 404) = error as? APIError {
                    tasks[url] = nil
                    return
                }
                if case .notFound = error as? APIError {
                    tasks[url] = nil
                    return
                }
                if case .rateLimited(let retryAfter) = error as? APIError {
                    delay = max(delay, retryAfter ?? 30)
                }
                failures += 1
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            }
        }
    }
}
