import Foundation
import Observation
import UIKit
import NHVCore

/// Batch registration preserves gallery order. Completion order never changes the grid.
@MainActor @Observable
final class ThumbnailStore {
    private(set) var revision = 0
    private(set) var cacheGeneration = 0
    private(set) var failures: Set<URL> = []
    private(set) var isClearingCache = false
    @ObservationIgnored private let cache = NSCache<NSURL, UIImage>()
    @ObservationIgnored private var queue = OrderedWorkQueue<URL>(concurrency: 6, batchSize: 6)
    @ObservationIgnored private var active: [URL: Task<Void, Never>] = [:]
    @ObservationIgnored private var resumeTask: Task<Void, Never>?
    @ObservationIgnored private var pausedUntil: Date?
    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private let diskCache = ImageDiskCache(namespace: "thumbnails")

    init() {
        cache.totalCostLimit = 48 * 1024 * 1024
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.httpMaximumConnectionsPerHost = 6
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        config.urlCache = nil
        session = URLSession(configuration: config)
    }

    func image(for url: URL) -> UIImage? {
        _ = revision
        return cache.object(forKey: url as NSURL)
    }

    func enqueue(_ urls: [URL]) {
        guard !isClearingCache else { return }
        queue.enqueue(urls.filter { cache.object(forKey: $0 as NSURL) == nil && !failures.contains($0) })
        pump()
    }

    func retry(_ url: URL) {
        failures.remove(url)
        enqueue([url])
    }

    func cancel() {
        resumeTask?.cancel()
        resumeTask = nil
        active.values.forEach { $0.cancel() }
        active.removeAll()
        queue.removeAll()
    }

    func clearCache() async throws {
        guard !isClearingCache else { return }
        isClearingCache = true
        defer { isClearingCache = false }
        let downloads = Array(active.values)
        cancel()
        // Wait for cancelled transfers/decoders before removing their cached responses.
        for download in downloads { await download.value }
        cache.removeAllObjects()
        failures.removeAll()
        cacheGeneration += 1
        revision += 1
        pausedUntil = nil
        try await diskCache.clear()
    }

    private func pump() {
        if let pausedUntil, pausedUntil > Date() {
            guard resumeTask == nil else { return }
            let delay = pausedUntil.timeIntervalSinceNow
            resumeTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self else { return }
                self.resumeTask = nil
                self.pump()
            }
            return
        }
        while let url = queue.next() {
            let session = session
            let diskCache = diskCache
            active[url] = Task { [weak self] in
                do {
                    let image = try await diskCache.image(for: url, session: session, maximumPixelSize: 600)
                    try Task.checkCancellation()
                    guard let self else { return }
                    let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                    self.cache.setObject(image, forKey: url as NSURL, cost: cost)
                    self.revision += 1
                } catch {
                    if !Task.isCancelled, case .rateLimited(let delay) = error as? APIError {
                        self?.pausedUntil = Date().addingTimeInterval(delay ?? 30)
                    }
                    if !Task.isCancelled { self?.failures.insert(url) }
                }
                guard !Task.isCancelled, let self else { return }
                self.active[url] = nil
                self.queue.finish(url)
                self.pump()
            }
        }
    }
}
