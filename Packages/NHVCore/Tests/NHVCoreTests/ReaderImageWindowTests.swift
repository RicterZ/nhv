import Foundation
import Testing
@testable import NHVCore

@Test func readerImageWindowPrioritizesCurrentAndFollowingPages() {
    let urls = (0..<6).map { URL(string: "https://example.com/\($0).webp")! as URL? }
    #expect(ReaderImageWindow(index: 2, urls: urls)?.requested == [urls[2]!, urls[3]!, urls[4]!, urls[1]!])
    #expect(ReaderImageWindow(index: 2, urls: urls)?.retained == Set([urls[1]!, urls[2]!, urls[3]!, urls[4]!]))
    #expect(ReaderImageWindow(index: 0, urls: urls)?.requested == [urls[0]!, urls[1]!, urls[2]!])
    #expect(ReaderImageWindow(index: 5, urls: urls)?.requested == [urls[5]!, urls[4]!])
}

@Test func readerImageWindowSkipsMissingAndDuplicateURLs() {
    let first = URL(string: "https://example.com/first.webp")!
    let second = URL(string: "https://example.com/second.webp")!
    let urls: [URL?] = [first, nil, second, first]
    let window = ReaderImageWindow(index: 1, urls: urls)
    #expect(window?.requested == [second, first, first])
    #expect(window?.retained == Set([first, second]))
    #expect(ReaderImageWindow(index: -1, urls: urls) == nil)
    #expect(ReaderImageWindow(index: urls.count, urls: urls) == nil)
    #expect(ReaderImageWindow(index: 0, urls: []) == nil)
}
