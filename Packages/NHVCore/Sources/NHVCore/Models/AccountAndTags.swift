import Foundation

public struct CurrentUser: Decodable, Identifiable, Sendable {
    public let id: Int
    public let username: String
    public let slug: String
    public let avatarUrl: String
    public let about: String
    public let favoriteTags: String

    private enum CodingKeys: String, CodingKey {
        case id, username, slug, avatarUrl, about, favoriteTags
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        username = try values.decode(String.self, forKey: .username)
        slug = try values.decode(String.self, forKey: .slug)
        avatarUrl = try values.decode(String.self, forKey: .avatarUrl)
        about = try values.decodeIfPresent(String.self, forKey: .about) ?? ""
        favoriteTags = try values.decodeIfPresent(String.self, forKey: .favoriteTags) ?? ""
    }
}

public struct Tag: Codable, Identifiable, Sendable {
    public let id: Int
    /// Keep server values intact, including future tag types.
    public let type: String
    public let name: String
    public let slug: String
    public let url: String
    public let count: Int
    public let description: String?

    public var searchQuery: String {
        let field: String
        switch type {
        case "artist", "group", "parody", "character", "language", "category": field = type
        case "author": field = "artist"
        default: field = "tag"
        }
        let escaped = name.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\(field):\"\(escaped)\""
    }
}

public enum TagType: String, CaseIterable, Sendable {
    case tag, artist, group, parody, character, language, category
}

public enum GallerySort: String, CaseIterable, Sendable {
    case date, popular
    case today = "popular-today"
    case week = "popular-week"
    case month = "popular-month"
}

public enum TagSort: String, Sendable {
    case name, popular
}

public struct PaginatedResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    public let result: [Item]
    public let numPages: Int
    public let perPage: Int
    public let total: Int?

    private enum CodingKeys: String, CodingKey { case result, numPages, perPage, total }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        result = try values.decode([Item].self, forKey: .result)
        numPages = try values.decode(Int.self, forKey: .numPages)
        perPage = try values.decodeIfPresent(Int.self, forKey: .perPage) ?? 25
        total = try values.decodeIfPresent(Int.self, forKey: .total)
    }
}

public struct CDNConfiguration: Codable, Sendable {
    public let imageServers: [String]
    public let thumbServers: [String]
}
