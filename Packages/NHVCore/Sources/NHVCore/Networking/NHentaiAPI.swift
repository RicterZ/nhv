import Foundation

public struct NHentaiAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) { self.client = client }

    public func handlingUnauthorized(_ handler: @escaping @Sendable () -> Void) -> Self {
        Self(client: client.handlingUnauthorized(handler))
    }

    public func currentUser() async throws -> CurrentUser {
        try await client.send(["user"])
    }

    public func cdnConfiguration() async throws -> CDNConfiguration {
        try await client.send(["cdn"], authenticated: false)
    }

    public func galleries(page: Int = 1, perPage: Int? = nil) async throws -> PaginatedResponse<GallerySummary> {
        try await client.send(["galleries"], query: pagination(page, perPage: perPage))
    }

    public func gallery(id: Int) async throws -> GalleryDetail {
        try validateID(id)
        return try await client.send(["galleries", String(id)], query: [.init(name: "include", value: "favorite")])
    }

    public func search(query: String, sort: GallerySort = .date, page: Int = 1) async throws -> PaginatedResponse<GallerySummary> {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.invalidInput(.emptySearch)
        }
        return try await client.send(["search"], query: pagination(page) + [
            .init(name: "query", value: query), .init(name: "sort", value: sort.rawValue)
        ])
    }

    public func favorites(query: String? = nil, page: Int = 1) async throws -> PaginatedResponse<GallerySummary> {
        var parameters = try pagination(page)
        if let query, !query.isEmpty { parameters.append(.init(name: "q", value: query)) }
        return try await client.send(["favorites"], query: parameters)
    }

    public func favorite(id: Int) async throws -> FavoriteResponse {
        try validateID(id)
        return try await client.send(["galleries", String(id), "favorite"])
    }

    public func setFavorite(id: Int, favorited: Bool) async throws -> FavoriteResponse {
        try validateID(id)
        return try await client.send(["galleries", String(id), "favorite"], method: favorited ? "POST" : "DELETE")
    }

    public func tags(type: TagType, sort: TagSort = .popular, page: Int = 1, perPage: Int = 25) async throws -> PaginatedResponse<Tag> {
        try await client.send(["tags", type.rawValue], query: pagination(page, perPage: perPage) + [.init(name: "sort", value: sort.rawValue)])
    }

    public func tag(type: TagType, slug: String) async throws -> Tag {
        guard !slug.isEmpty else { throw APIError.invalidInput(.tagSlug) }
        return try await client.send(["tags", type.rawValue, slug])
    }

    public func searchTags(query: String, type: TagType? = nil, limit: Int = 10) async throws -> [Tag] {
        guard (1...50).contains(limit) else { throw APIError.invalidInput(.tagLimit) }
        struct Body: Encodable { let query: String; let type: String?; let limit: Int }
        let body = try JSONEncoder().encode(Body(query: query, type: type?.rawValue, limit: limit))
        return try await client.send(["tags", "search"], method: "POST", body: body)
    }

    private func pagination(_ page: Int, perPage: Int? = nil) throws -> [URLQueryItem] {
        guard page >= 1 else { throw APIError.invalidInput(.page) }
        var items = [URLQueryItem(name: "page", value: String(page))]
        if let perPage {
            guard (1...100).contains(perPage) else { throw APIError.invalidInput(.pageSize) }
            items.append(.init(name: "per_page", value: String(perPage)))
        }
        return items
    }

    private func validateID(_ id: Int) throws {
        guard id > 0 else { throw APIError.invalidInput(.identifier) }
    }
}
