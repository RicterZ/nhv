import Foundation
import Testing
@testable import NHVCore

private func searchTag(type: String, name: String) throws -> NHVCore.Tag {
    let data = try JSONSerialization.data(withJSONObject: [
        "id": 42, "type": type, "name": name, "slug": "fixture", "url": "/tag/fixture/", "count": 1
    ])
    return try JSONDecoder().decode(NHVCore.Tag.self, from: data)
}

@Test(arguments: ["tag", "artist", "group", "parody", "character", "language", "category"])
func tagClicksSearchUsingTheirType(type: String) async throws {
    let tag = try searchTag(type: type, name: "some name")
    #expect(tag.searchQuery == "\(type):\"some name\"")
    let transport = StubTransport(emptyPage)
    _ = try await makeAPI(transport).galleries(matching: .search(tag.searchQuery, .popular), page: 1)
    let request = try #require(await transport.captured().first)
    #expect(request.url?.path == "/api/v2/search")
    let parameters = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems)
    #expect(parameters.first { $0.name == "query" }?.value == tag.searchQuery)
    #expect(parameters.first { $0.name == "sort" }?.value == "popular")
    #expect(!parameters.contains { $0.name == "tag_id" })
}

@Test func tagSearchEscapesNamesAndHandlesAuthorAlias() throws {
    let tag = try searchTag(type: "tag", name: #"a "quoted" name\suffix"#)
    #expect(tag.searchQuery == #"tag:"a \"quoted\" name\\suffix""#)
    #expect(SearchTerms.split(tag.searchQuery) == [tag.searchQuery])
    #expect(try searchTag(type: "author", name: "name").searchQuery == #"artist:"name""#)
    #expect(try searchTag(type: "future", name: "name").searchQuery == #"tag:"name""#)
}

@Test func explicitLanguageSearchOverridesAutomaticLanguageFilter() {
    let query = GalleryQuery.search(#"language:"japanese""#, .date)
    #expect(query.filtered(language: .english) == query)
    let other = GalleryQuery.search(#"artist:"some language: name""#, .date)
    #expect(other.filtered(language: .english) == .search(#"language:english artist:"some language: name""#, .date))
}
