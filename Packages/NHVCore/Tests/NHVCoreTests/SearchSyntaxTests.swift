import Testing
@testable import NHVCore

@Test func staticSyntaxMatchesPrefixAndSupportsExclusion() {
    #expect(SearchSyntax.suggestions(for: "art").map(\.id) == ["artist"])
    #expect(SearchSyntax.suggestions(for: "-art").map(\.id) == ["artist"])
    #expect(SearchSyntax.suggestions(for: "-").count == SearchSyntax.all.count - 1)
    #expect(SearchSyntax.suggestions(for: "pages:>20").isEmpty)
    #expect(SearchSyntax.suggestions(for: "unrelated").isEmpty)
}

@Test func syntaxInsertionPreservesEarlierTermsAndMinusPrefix() throws {
    let artist = try #require(SearchSyntax.all.first { $0.id == "artist" })
    #expect(artist.applying(to: "language:english -art") == "language:english -artist:\"\"")
    #expect(artist.applying(to: #"tag:"some tag" art"#) == "tag:\"some tag\" artist:\"\"")
    #expect(artist.applying(to: "") == "artist:\"\"")
    #expect(artist.applying(to: "foo ") == "foo artist:\"\"")
}

@Test func syntaxCompletionDoesNotSplitQuotedPhrases() throws {
    #expect(SearchSyntax.suggestions(for: #"title:"some art"#).isEmpty)
    let title = try #require(SearchSyntax.all.first { $0.id == "title" })
    #expect(title.applying(to: "-tit") == "-title:\"\"")
    #expect(SearchSyntax.suggestions(for: #"title:"some words" jt"#).map(\.id) == ["jtitle"])
}

@Test(arguments: ["tag", "artist", "parody", "character", "group", "language", "category", "title", "jtitle", "phrase"])
func quotedCompletionPlacesTypedTextInsideQuotes(id: String) throws {
    let syntax = try #require(SearchSyntax.all.first { $0.id == id })
    let completion = syntax.completion(in: "title:\"日本語📚\" -")
    var text = completion.text
    let caret = String.Index(utf16Offset: completion.caretUTF16Offset, in: text)
    text.insert(contentsOf: "some words", at: caret)
    let prefix = id == "phrase" ? "" : "\(id):"
    #expect(text == "title:\"日本語📚\" -\(prefix)\"some words\"")
    #expect(SearchTerms.split(text).count == 2)
}

@Test(arguments: ["pages", "favorites", "uploaded"])
func numericCompletionLeavesCaretAfterColon(id: String) throws {
    let syntax = try #require(SearchSyntax.all.first { $0.id == id })
    let completion = syntax.completion(in: "-")
    #expect(completion.text == "-\(id):")
    #expect(completion.caretUTF16Offset == completion.text.utf16.count)
}
