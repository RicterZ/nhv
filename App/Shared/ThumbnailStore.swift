import Foundation
import ImageIO
import Observation
import UIKit
import NHVCore

/// Batch registration preserves gallery order. Completion order never changes the grid.
@MainActor @Observable
final class ThumbnailStore {
    private(set) var revision = 0
    private(set) var failures: Set<URL> = []
    @ObservationIgnored private let cache = NSCache<NSURL, UIImage>()
    @ObservationIgnored private var queue = OrderedWorkQueue<URL>(concurrency: 4)
    @ObservationIgnored private var active: [URL: Task<Void, Never>] = [:]
    @ObservationIgnored private var resumeTask: Task<Void, Never>?
    @ObservationIgnored private var pausedUntil: Date?
    @ObservationIgnored private let session: URLSession

    init() {
        cache.totalCostLimit = 48 * 1024 * 1024
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        config.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 96 * 1024 * 1024)
        session = URLSession(configuration: config)
    }

    func image(for url: URL) -> UIImage? {
        _ = revision
        return cache.object(forKey: url as NSURL)
    }

    func enqueue(_ urls: [URL]) {
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
            active[url] = Task { [weak self] in
                do {
                    var request = URLRequest(url: url)
                    request.setValue(AppConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
                    let (data, response) = try await session.data(for: request)
                    try Task.checkCancellation()
                    guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
                    if response.statusCode == 429 {
                        let delay = Double(response.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 30
                        self?.pausedUntil = Date().addingTimeInterval(delay.isFinite ? max(1, delay) : 30)
                        throw APIError.rateLimited(retryAfter: delay)
                    }
                    guard (200..<300).contains(response.statusCode) else { throw APIError.server(status: response.statusCode) }
                    let image = await Task.detached(priority: .utility) {
                        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return UIImage?.none }
                        let options: [CFString: Any] = [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceThumbnailMaxPixelSize: 600,
                            kCGImageSourceShouldCacheImmediately: true
                        ]
                        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return UIImage?.none }
                        return UIImage(cgImage: cgImage)
                    }.value
                    try Task.checkCancellation()
                    guard let self, let image else { throw APIError.decoding }
                    let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                    self.cache.setObject(image, forKey: url as NSURL, cost: cost)
                    self.revision += 1
                } catch {
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
