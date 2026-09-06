import Testing
@testable import NHVCore

@Test func directGalleryIDAcceptsOnlyStandalonePositiveASCIIDigits() throws {
    #expect(try SearchTerms.directGalleryID(in: "id:123456") == 123456)
    #expect(try SearchTerms.directGalleryID(in: "  ID:00123\n") == 123)
    for input in ["id:", "id:abc", "id:12a", "id:1.2", "id:-1", "id:+1", "id:0", "id:１２３", "id:١٢٣", "id:999999999999999999999999", "id: 123", "id:123 tag:foo", "tag:foo id:123", "id:1 id:2"] {
        #expect(throws: SearchTerms.DirectIDError.self) { try SearchTerms.directGalleryID(in: input) }
    }
    for input in ["123456", "artist:abc", "-id:123", "title:\"id:123\"", ""] {
        #expect(try SearchTerms.directGalleryID(in: input) == nil)
    }
}

@Test func directGalleryIDSyntaxCompletion() throws {
    #expect(SearchSyntax.suggestions(for: "id").map(\.id) == ["id"])
    #expect(SearchSyntax.suggestions(for: "-id").isEmpty)
    let syntax = try #require(SearchSyntax.all.first { $0.id == "id" })
    #expect(syntax.completion(in: "id").text == "id:")
    #expect(syntax.completion(in: "id").caretUTF16Offset == 3)
}
