import Foundation
import ImageIO
import NHVCore
import Observation
import UIKit

@MainActor @Observable
final class ReaderImageStore {
    private(set) var images: [URL: UIImage] = [:]
    @ObservationIgnored private var tasks: [URL: Task<Void, Never>] = [:]
    @ObservationIgnored private var wanted: Set<URL> = []
    @ObservationIgnored private let responseCache: URLCache
    @ObservationIgnored private let session: URLSession

    init(configuration: URLSessionConfiguration = .ephemeral) {
        let cache = URLCache(memoryCapacity: 0, diskCapacity: 256 * 1024 * 1024, diskPath: "reader-images")
        responseCache = cache
        configuration.urlCache = cache
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.httpMaximumConnectionsPerHost = 3
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 45
        session = URLSession(configuration: configuration)
    }

    /// Register the visible page first, followed by exactly the next two pages.
    func focus(on index: Int, urls: [URL?]) {
        guard urls.indices.contains(index) else { return }
        let requested = urls[index..<min(urls.count, index + 3)].compactMap { $0 }
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

    func cancel() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        wanted.removeAll()
        images.removeAll()
    }

    func clearCache() async {
        let pending = Array(tasks.values)
        cancel()
        for task in pending { await task.value }
        responseCache.removeAllCachedResponses()
    }

    private func load(_ url: URL) async {
        var failures = 0
        while !Task.isCancelled && wanted.contains(url) {
            var delay = min(30.0, pow(2, Double(min(failures, 5))))
            do {
                var request = URLRequest(url: url)
                request.setValue(AppConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
                if failures > 0 { request.cachePolicy = .reloadIgnoringLocalCacheData }
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
                if let seconds = response.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init), seconds.isFinite {
                    delay = max(delay, seconds)
                }
                guard (200..<300).contains(response.statusCode) else { throw APIError.server(status: response.statusCode) }
                let image = await Task.detached(priority: .userInitiated) {
                    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return UIImage?.none }
                    let options: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 4096,
                        kCGImageSourceShouldCacheImmediately: true,
                    ]
                    guard let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return UIImage?.none }
                    return UIImage(cgImage: bitmap)
                }.value
                try Task.checkCancellation()
                guard let image else { throw APIError.decoding }
                guard wanted.contains(url) else { return }
                images[url] = image
                tasks[url] = nil
                return
            } catch {
                if Task.isCancelled { return }
                failures += 1
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            }
        }
    }
}
