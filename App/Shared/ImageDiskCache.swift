import CryptoKit
import Foundation
import ImageIO
import NHVCore
import UIKit

/// Compressed image files survive memory eviction and app restarts. Each image
/// store owns a namespace; disk access is serialized off the main actor.
actor ImageDiskCache {
    private let namespace: String
    private var generation = UUID()

    init(namespace: String) { self.namespace = namespace }

    private func directory() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("DownloadedImages", isDirectory: true)
        var directory = root.appendingPathComponent(namespace, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory
    }

    private func file(for url: URL) throws -> URL {
        let key = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return try directory().appendingPathComponent(key)
    }

    func image(for url: URL, session: URLSession, maximumPixelSize: Int) async throws -> UIImage {
        let operation = generation
        let file = try? self.file(for: url)
        if let file, let data = try? Data(contentsOf: file) {
            if let image = await Self.decode(data, maximumPixelSize: maximumPixelSize) {
                try Task.checkCancellation()
                guard operation == generation else { throw CancellationError() }
                return image
            }
            try Task.checkCancellation()
            guard operation == generation else { throw CancellationError() }
            // An invalid local file should not cause an endless decoding loop.
            try? FileManager.default.removeItem(at: file)
        }

        try Task.checkCancellation()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue(AppConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if response.statusCode == 429 {
            throw APIError.rateLimited(retryAfter: Self.retryDelay(response.value(forHTTPHeaderField: "Retry-After")))
        }
        guard (200..<300).contains(response.statusCode) else { throw APIError.server(status: response.statusCode) }
        guard let image = await Self.decode(data, maximumPixelSize: maximumPixelSize) else { throw APIError.decoding }
        try Task.checkCancellation()
        guard operation == generation else { throw CancellationError() }
        // A full or unwritable disk must not prevent displaying a downloaded image.
        if let file { try? data.write(to: file, options: .atomic) }
        return image
    }

    func clear() throws {
        generation = UUID()
        let directory = try directory()
        try FileManager.default.removeItem(at: directory)
    }

    private static func retryDelay(_ value: String?) -> TimeInterval {
        guard let value else { return 30 }
        if let seconds = Double(value), seconds.isFinite { return max(1, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return max(1, formatter.date(from: value)?.timeIntervalSinceNow ?? 30)
    }

    private static func decode(_ data: Data, maximumPixelSize: Int) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return UIImage(cgImage: bitmap)
        }.value
    }
}
