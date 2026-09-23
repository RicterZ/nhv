import Testing
import UIKit
@testable import NHV

@MainActor private func image(width: Int, height: Int = 1) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

@Test @MainActor func decodedImageCacheEvictsLeastRecentlyUsedImage() {
    let bitmap = image(width: 1)
    let cost = bitmap.cgImage!.bytesPerRow * bitmap.cgImage!.height
    let cache = DecodedImageCache(costLimit: cost * 2)
    let first = URL(string: "https://example.com/first")!
    let second = URL(string: "https://example.com/second")!
    let third = URL(string: "https://example.com/third")!
    cache.insert(bitmap, for: first)
    cache.insert(bitmap, for: second)
    #expect(cache.image(for: first) != nil)
    cache.insert(bitmap, for: third)
    #expect(cache.contains(first))
    #expect(!cache.contains(second))
    #expect(cache.contains(third))
}

@Test @MainActor func decodedImageCacheKeepsOversizedImageAndClearsEntries() {
    let cache = DecodedImageCache(costLimit: 4)
    let first = URL(string: "https://example.com/first")!
    let second = URL(string: "https://example.com/second")!
    cache.insert(image(width: 2), for: first)
    #expect(cache.contains(first))
    cache.insert(image(width: 1), for: second)
    #expect(!cache.contains(first))
    #expect(cache.contains(second))
    cache.removeAll()
    #expect(!cache.contains(second))
}
