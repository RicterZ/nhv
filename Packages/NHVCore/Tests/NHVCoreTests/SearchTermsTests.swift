import Testing
@testable import NHVCore

@Test func splitsSearchWhitespaceAndPreservesFilterSyntax() {
    #expect(SearchTerms.split("  artist:name\t-language:japanese\n pages:>10 ") == [
        "artist:name", "-language:japanese", "pages:>10"
    ])
    #expect(SearchTerms.split("  \n\t").isEmpty)
}

@Test func keepsQuotedSearchPhrasesTogether() {
    #expect(SearchTerms.split(#"tag:"some tag" -"exact phrase" keyword"#) == [
        #"tag:"some tag""#, #"-"exact phrase""#, "keyword"
    ])
}

@Test func keepsEscapedQuotesAndIncompletePhrasesIntact() {
    #expect(SearchTerms.split(#""a \"quoted\" phrase" next"#) == [#""a \"quoted\" phrase""#, "next"])
    #expect(SearchTerms.split(#"tag:"unfinished phrase"#) == [#"tag:"unfinished phrase"#])
}
