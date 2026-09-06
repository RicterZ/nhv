import Foundation

public enum GalleryQuery: Hashable, Sendable {
    case latest
    case favorites(String)
    case search(String, GallerySort)
    case tag(Int, GallerySort)

    /// Filter server-side, so pagination and totals reflect the chosen language.
    public func filtered(language: AppLanguage?) -> GalleryQuery {
        guard let language else { return self }
        let filter = "language:\(language.definition.galleryTag)"
        switch self {
        case .latest:
            return .search(filter, .date)
        case .search(let text, let sort):
            // Put the constraint first so an unfinished quote cannot absorb it.
            return .search(text.isEmpty ? filter : "\(filter) \(text)", sort)
        case .favorites, .tag:
            return self
        }
    }
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
