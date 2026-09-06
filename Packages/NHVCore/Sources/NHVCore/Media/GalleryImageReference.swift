import Foundation

public struct GalleryImageReference: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case thumbnail, cover, pageThumbnail(Int), page(Int)
    }
    public let galleryID: Int
    public let kind: Kind

    public init(galleryID: Int, kind: Kind) {
        self.galleryID = galleryID
        self.kind = kind
    }

    public var cacheKey: String {
        let suffix: String
        switch kind {
        case .thumbnail: suffix = "thumbnail"
        case .cover: suffix = "cover"
        case .pageThumbnail(let n): suffix = "thumbnail-\(n)"
        case .page(let n): suffix = "page-\(n)"
        }
        return "gallery-\(galleryID)-\(suffix)"
    }

    public func path(in gallery: GalleryDetail) -> String? {
        guard gallery.id == galleryID else { return nil }
        switch kind {
        case .thumbnail: return gallery.thumbnail.path
        case .cover: return gallery.cover.path
        case .pageThumbnail(let n): return gallery.pages.first { $0.number == n }?.thumbnail
        case .page(let n): return gallery.pages.first { $0.number == n }?.path
        }
    }
}
