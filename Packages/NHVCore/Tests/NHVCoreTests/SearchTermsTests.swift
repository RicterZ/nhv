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

@Test func escapedWhitespaceAndTrailingEscapeStayInTheirTerms() {
    #expect(SearchTerms.split("one\\ two three\\\tfour") == ["one\\ two", "three\\\tfour"])
    #expect(SearchTerms.split("artist:abc\\") == ["artist:abc\\"])
    #expect(SearchTerms.split("a  b\\ c  d") == ["a", "b\\ c", "d"])
}
