import Foundation
import Testing
import UIKit
import NHVCore
@testable import NHV

private final class ImageFixtureProtocol: URLProtocol {
    nonisolated(unsafe) static var requests: [URL] = []
    private static let lock = NSLock()
    nonisolated(unsafe) static var response: @Sendable (URL) -> (Int, Data) = { _ in (404, Data()) }

    static func configure(_ handler: @escaping @Sendable (URL) -> (Int, Data)) {
        lock.withLock { requests = []; response = handler }
    }

    static func captured() -> [URL] { lock.withLock { requests } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        let (status, data) = Self.lock.withLock { () -> (Int, Data) in
            Self.requests.append(url)
            return Self.response(url)
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status,
            httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized) struct ImageDiskCacheTests {
@Test func imageDiskCacheRecovers404OnlyOnceAndReusesReplacement() async throws {
    let original = URL(string: "https://example.com/old.png")!
    let replacement = URL(string: "https://example.com/new.png")!
    let image = await MainActor.run {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
    ImageFixtureProtocol.configure { url in url == replacement ? (200, image) : (404, Data()) }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ImageFixtureProtocol.self]
    let session = URLSession(configuration: configuration)
    let cache = ImageDiskCache(namespace: "ImageDiskCacheTests-\(UUID())")
    let first = try await cache.image(for: original, cacheKey: "same-image", session: session,
        maximumPixelSize: 32, recover: { replacement })
    #expect(first.size.width > 0)
    #expect(ImageFixtureProtocol.captured() == [original, replacement])
    let cached = try await cache.image(for: original, cacheKey: "same-image", session: session,
        maximumPixelSize: 32)
    #expect(cached.size.width > 0)
    #expect(ImageFixtureProtocol.captured() == [original, replacement])
    #expect(try await cache.sizeInBytes() > 0)
    try await cache.clear()
    #expect(try await cache.sizeInBytes() == 0)
}

@Test func imageDiskCacheUsesReferenceIdentityAndRecovery() async throws {
    let original = URL(string: "https://example.com/old-cover.png")!
    let replacement = URL(string: "https://example.com/new-cover.png")!
    let reference = GalleryImageReference(galleryID: 42, kind: .cover)
    let image = await MainActor.run {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
    ImageFixtureProtocol.configure { url in url == replacement ? (200, image) : (404, Data()) }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ImageFixtureProtocol.self]
    let session = URLSession(configuration: configuration)
    let cache = ImageDiskCache(namespace: "ImageDiskCacheTests-\(UUID())")
    let loaded = try await cache.image(for: original, reference: reference, session: session,
        maximumPixelSize: 32, recover: { input in
            #expect(input == reference)
            return replacement
        })
    #expect(loaded.size.width > 0)
    #expect(ImageFixtureProtocol.captured() == [original, replacement])
    let cached = try await cache.cachedImage(cacheKey: reference.cacheKey, maximumPixelSize: 32)
    #expect(cached != nil)
    try await cache.clear()
}
}
