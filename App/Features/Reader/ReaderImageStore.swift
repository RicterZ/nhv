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
    func focus(on index: Int, urls: [URL?]) {
        guard !isClearingCache, urls.indices.contains(index) else { return }
        var requested = urls[index..<min(urls.count, index + 3)].compactMap { $0 }
        if index > 0, let previous = urls[index - 1] { requested.append(previous) }
        wanted = Set(requested)
        for url in Array(tasks.keys) where !wanted.contains(url) {
            tasks.removeValue(forKey: url)?.cancel()
        }
        // Keep one previous decoded page for quick back navigation.
        let retained = Set(urls[max(0, index - 1)..<min(urls.count, index + 3)].compactMap { $0 })
        images = images.filter { retained.contains($0.key) }
        for url in requested where images[url] == nil && tasks[url] == nil {
            tasks[url] = Task { [weak self] in await self?.load(url) }
        }
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
                let recovery: (@Sendable () async throws -> URL)?
                if let reference, let recover {
                    recovery = { try await recover(reference) }
                } else { recovery = nil }
                let image = try await diskCache.image(for: url, cacheKey: reference?.cacheKey ?? url.path,
                    session: session, maximumPixelSize: 4096, recover: recovery)
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
