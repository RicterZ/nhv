import Foundation

public enum GalleryQuery: Hashable, Sendable {
    case latest
    case favorites(String)
    case search(String, GallerySort)
    case tag(Int, GallerySort)
}

extension NHentaiAPI {
    public func galleries(matching query: GalleryQuery, page: Int) async throws -> PaginatedResponse<GallerySummary> {
        switch query {
        case .latest: try await galleries(page: page)
        case .favorites(let text): try await favorites(query: text.isEmpty ? nil : text, page: page)
        case .search(let text, let sort): try await search(query: text, sort: sort, page: page)
        case .tag(let id, let sort): try await galleries(tagID: id, sort: sort, page: page)
        }
    }
}
