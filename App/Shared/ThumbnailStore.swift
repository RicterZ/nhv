import Foundation
import Observation
import UIKit
import NHVCore

/// Disk reads never wait for network slots; completion order never changes the grid.
@MainActor @Observable
final class ThumbnailStore {
    private(set) var revision = 0
    private(set) var cacheGeneration = 0
    private(set) var failures: Set<URL> = []
    private(set) var isClearingCache = false
    @ObservationIgnored private let cache = DecodedImageCache()
    @ObservationIgnored private var queue = OrderedWorkQueue<URL>(concurrency: 6)
    @ObservationIgnored private var diskQueue = OrderedWorkQueue<URL>(concurrency: 4)
    @ObservationIgnored private var diskReads: [URL: Task<Void, Never>] = [:]
    @ObservationIgnored private var scheduled: Set<URL> = []
    @ObservationIgnored private var active: [URL: Task<Void, Never>] = [:]
    @ObservationIgnored private var resumeTask: Task<Void, Never>?
    @ObservationIgnored private var pausedUntil: Date?
    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private let diskCache: ImageDiskCache
    @ObservationIgnored var references: [URL: GalleryImageReference] = [:]
    @ObservationIgnored var recover: (@Sendable (GalleryImageReference) async throws -> URL)?

    init(session: URLSession? = nil, diskCache: ImageDiskCache = ImageDiskCache(namespace: "thumbnails")) {
        self.diskCache = diskCache
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.httpMaximumConnectionsPerHost = 6
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        config.urlCache = nil
        self.session = session ?? URLSession(configuration: config)
    }

    func image(for url: URL) -> UIImage? {
        _ = revision
        return cache.image(for: url)
    }

    func enqueue(_ urls: [URL]) {
        guard !isClearingCache else { return }
        diskQueue.enqueue(urls.filter {
            !cache.contains($0) && !failures.contains($0) && scheduled.insert($0).inserted
        })
        pumpDiskReads()
    }

    func retry(_ url: URL) {
        failures.remove(url)
        enqueue([url])
    }

    func cancel() {
        resumeTask?.cancel()
        resumeTask = nil
        diskReads.values.forEach { $0.cancel() }
        diskReads.removeAll()
        diskQueue.removeAll()
        scheduled.removeAll()
        active.values.forEach { $0.cancel() }
        active.removeAll()
        queue.removeAll()
    }

    func diskCacheSize() async throws -> Int64 {
        try await diskCache.sizeInBytes()
    }

    func clearCache() async throws {
        guard !isClearingCache else { return }
        isClearingCache = true
        defer { isClearingCache = false }
        let downloads = Array(active.values) + Array(diskReads.values)
        cancel()
        // Wait for cancelled transfers/decoders before removing their cached responses.
        for download in downloads { await download.value }
        cache.removeAll()
        failures.removeAll()
        cacheGeneration += 1
        revision += 1
        pausedUntil = nil
        try await diskCache.clear()
    }

    private func pumpDiskReads() {
        while let url = diskQueue.next() {
            let diskCache = diskCache
            let key = references[url]?.cacheKey ?? url.path
            diskReads[url] = Task { [weak self] in
                let image = try? await diskCache.cachedImage(cacheKey: key, maximumPixelSize: 600)
                guard !Task.isCancelled, let self else { return }
                if let image {
                    self.cache.insert(image, for: url)
                    self.revision += 1
                    self.scheduled.remove(url)
                } else {
                    self.queue.enqueue([url])
                }
                self.diskReads[url] = nil
                self.diskQueue.finish(url)
                self.pumpDiskReads()
                self.pump()
            }
        }
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
            let reference = references[url]
            let recover = recover
            active[url] = Task { [weak self] in
                do {
                    let recovery: (@Sendable () async throws -> URL)?
                    if let reference, let recover {
                        recovery = { try await recover(reference) }
                    } else { recovery = nil }
                    let image = try await diskCache.image(for: url, cacheKey: reference?.cacheKey ?? url.path,
                        session: session, maximumPixelSize: 600, recover: recovery)
                    try Task.checkCancellation()
                    guard let self else { return }
                    self.cache.insert(image, for: url)
                    self.revision += 1
                } catch {
                    if !Task.isCancelled, case .rateLimited(let delay) = error as? APIError {
                        self?.pausedUntil = Date().addingTimeInterval(delay ?? 30)
                    }
                    if !Task.isCancelled { self?.failures.insert(url) }
                }
                guard !Task.isCancelled, let self else { return }
                self.scheduled.remove(url)
                self.active[url] = nil
                self.queue.finish(url)
                self.pump()
            }
        }
    }
}
