import Foundation

/// Keeps reader prefetch priority and decoded-image retention in sync.
public struct ReaderImageWindow {
    public let requested: [URL]
    public let retained: Set<URL>

    public init?(index: Int, urls: [URL?]) {
        guard urls.indices.contains(index) else { return nil }
        var requested = urls[index..<min(urls.count, index + 3)].compactMap { $0 }
        if index > 0, let previous = urls[index - 1] { requested.append(previous) }
        self.requested = requested
        retained = Set(requested)
    }
}
