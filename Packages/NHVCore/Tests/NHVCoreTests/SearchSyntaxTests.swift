import Testing
@testable import NHVCore

@Test func staticSyntaxMatchesPrefixAndSupportsExclusion() {
    #expect(SearchSyntax.suggestions(for: "art").map(\.id) == ["artist"])
    #expect(SearchSyntax.suggestions(for: "-art").map(\.id) == ["artist"])
    #expect(SearchSyntax.suggestions(for: "-").count == SearchSyntax.all.count)
    #expect(SearchSyntax.suggestions(for: "pages:>20").isEmpty)
    #expect(SearchSyntax.suggestions(for: "unrelated").isEmpty)
}

@Test func syntaxInsertionPreservesEarlierTermsAndMinusPrefix() throws {
    let artist = try #require(SearchSyntax.all.first { $0.id == "artist" })
    #expect(artist.applying(to: "language:english -art") == "language:english -artist:")
    #expect(artist.applying(to: #"tag:"some tag" art"#) == #"tag:"some tag" artist:"#)
    #expect(artist.applying(to: "") == "artist:")
    #expect(artist.applying(to: "foo ") == "foo artist:")
}

@Test func syntaxCompletionDoesNotSplitQuotedPhrases() throws {
    #expect(SearchSyntax.suggestions(for: #"title:"some art"#).isEmpty)
    let title = try #require(SearchSyntax.all.first { $0.id == "title" })
    #expect(title.applying(to: "-tit") == #"-title:""#)
    #expect(SearchSyntax.suggestions(for: #"title:"some words" jt"#).map(\.id) == ["jtitle"])
}
