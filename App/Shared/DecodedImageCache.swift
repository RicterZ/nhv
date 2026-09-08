import UIKit

/// Predictable LRU eviction: tab transitions cannot purge decoded images at
/// arbitrary times, while the cache still has a fixed decoded-memory budget.
@MainActor
final class DecodedImageCache {
    private struct Entry {
        let image: UIImage
        let cost: Int
        var access: UInt64
    }
    private let costLimit: Int
    private var entries: [URL: Entry] = [:]
    private var cost = 0
    private var clock: UInt64 = 0

    init(costLimit: Int = 128 * 1024 * 1024) { self.costLimit = costLimit }

    func image(for url: URL) -> UIImage? {
        guard var entry = entries[url] else { return nil }
        clock &+= 1
        entry.access = clock
        entries[url] = entry
        return entry.image
    }

    func contains(_ url: URL) -> Bool { entries[url] != nil }

    func insert(_ image: UIImage, for url: URL) {
        let imageCost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        if let old = entries.removeValue(forKey: url) { cost -= old.cost }
        clock &+= 1
        entries[url] = Entry(image: image, cost: imageCost, access: clock)
        cost += imageCost
        while cost > costLimit, entries.count > 1,
              let oldest = entries.min(by: { $0.value.access < $1.value.access })?.key {
            cost -= entries.removeValue(forKey: oldest)!.cost
        }
    }

    func removeAll() {
        entries.removeAll()
        cost = 0
    }
}
