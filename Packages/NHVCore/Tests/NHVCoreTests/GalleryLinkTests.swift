import Testing
@testable import NHVCore

@Test func galleryLinksExtractIDAndIgnoreReaderPage() {
    for text in ["https://nhentai.net/g/123", "https://nhentai.net/g/123/", "http://nhentai.net/g/123/7", "https://nhentai.net/g/123/7/", " \nHTTPS://NHENTAI.NET/g/00123/99/\n"] {
        #expect(GalleryLink.id(in: text) == 123)
    }
}

@Test func galleryLinksRejectInvalidHostsPathsAndIDs() {
    for text in ["", "123", "id:123", "https://nhentai.net.evil/g/123", "https://evil/nhentai.net/g/123", "https://nhentai.net@g.example/g/123", "ftp://nhentai.net/g/123", "https://nhentai.net/g/0", "https://nhentai.net/g/-123", "https://nhentai.net/g/１２３", "https://nhentai.net/g/12x", "https://nhentai.net/g/123/abc", "https://nhentai.net/g/123//", "https://nhentai.net/g/123/4/5", "https://nhentai.net/g/999999999999999999999999999", "https://nhentai.net/g/123\nhttps://nhentai.net/g/456"] {
        #expect(GalleryLink.id(in: text) == nil)
    }
}
