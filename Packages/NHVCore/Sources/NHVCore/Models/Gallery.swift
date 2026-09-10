import Foundation

public struct GallerySummary: Codable, Identifiable, Sendable {
    public let id: Int
    public let mediaId: String
    public let englishTitle: String
    public let japaneseTitle: String?
    public let thumbnail: String
    public let thumbnailWidth: Int
    public let thumbnailHeight: Int
    public let numPages: Int
    public let numFavorites: Int
    public let tagIds: [Int]
    public let blacklisted: Bool

    private enum CodingKeys: String, CodingKey {
        case id, mediaId, englishTitle, japaneseTitle, thumbnail, thumbnailWidth, thumbnailHeight
        case numPages, numFavorites, tagIds, blacklisted
    }

    public init(detail: GalleryDetail) {
        id = detail.id
        mediaId = detail.mediaId
        englishTitle = detail.title.english
        japaneseTitle = detail.title.japanese
        thumbnail = detail.thumbnail.path
        thumbnailWidth = detail.thumbnail.width
        thumbnailHeight = detail.thumbnail.height
        numPages = detail.numPages
        numFavorites = detail.numFavorites
        tagIds = detail.tags.map(\.id)
        blacklisted = false
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        mediaId = try values.decode(String.self, forKey: .mediaId)
        englishTitle = try values.decode(String.self, forKey: .englishTitle)
        japaneseTitle = try values.decodeIfPresent(String.self, forKey: .japaneseTitle)
        thumbnail = try values.decode(String.self, forKey: .thumbnail)
        thumbnailWidth = try values.decode(Int.self, forKey: .thumbnailWidth)
        thumbnailHeight = try values.decode(Int.self, forKey: .thumbnailHeight)
        numPages = try values.decodeIfPresent(Int.self, forKey: .numPages) ?? 0
        numFavorites = try values.decodeIfPresent(Int.self, forKey: .numFavorites) ?? 0
        tagIds = try values.decodeIfPresent([Int].self, forKey: .tagIds) ?? []
        blacklisted = try values.decodeIfPresent(Bool.self, forKey: .blacklisted) ?? false
    }
}

public struct GalleryDetail: Codable, Identifiable, Sendable {
    public let id: Int
    public let mediaId: String
    public let title: GalleryTitle
    public let cover: MediaImage
    public let thumbnail: MediaImage
    public let scanlator: String
    public let uploadDate: Int
    public let tags: [Tag]
    public let numPages: Int
    public let numFavorites: Int
    public let pages: [GalleryPage]
    /// Nil means unknown, never "not favorited".
    public let isFavorited: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, mediaId, title, cover, thumbnail, scanlator, uploadDate, tags
        case numPages, numFavorites, pages, isFavorited
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        mediaId = try values.decode(String.self, forKey: .mediaId)
        title = try values.decode(GalleryTitle.self, forKey: .title)
        cover = try values.decode(MediaImage.self, forKey: .cover)
        thumbnail = try values.decode(MediaImage.self, forKey: .thumbnail)
        scanlator = try values.decodeIfPresent(String.self, forKey: .scanlator) ?? ""
        uploadDate = try values.decode(Int.self, forKey: .uploadDate)
        tags = try values.decode([Tag].self, forKey: .tags)
        numPages = try values.decode(Int.self, forKey: .numPages)
        numFavorites = try values.decode(Int.self, forKey: .numFavorites)
        pages = try values.decodeIfPresent([GalleryPage].self, forKey: .pages) ?? []
        isFavorited = try values.decodeIfPresent(Bool.self, forKey: .isFavorited)
    }
}

public struct GalleryTitle: Codable, Sendable {
    public let english: String
    public let japanese: String?
    public let pretty: String
}

public struct MediaImage: Codable, Sendable {
    public let path: String
    public let width: Int
    public let height: Int
}

public struct GalleryPage: Codable, Identifiable, Sendable {
    public var id: Int { number }
    public let number: Int
    public let path: String
    public let width: Int
    public let height: Int
    public let thumbnail: String
    public let thumbnailWidth: Int
    public let thumbnailHeight: Int
}

public struct FavoriteResponse: Decodable, Sendable {
    public let favorited: Bool
    public let numFavorites: Int?
}

public struct RelatedGalleriesResponse: Decodable, Sendable {
    public let result: [GallerySummary]
}
