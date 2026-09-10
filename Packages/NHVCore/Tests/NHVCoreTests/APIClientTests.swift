import Foundation
import Testing
@testable import NHVCore

actor StubTransport: HTTPTransport {
    private var requests: [URLRequest] = []
    private let body: String
    private let status: Int
    private let headers: [String: String]

    init(_ body: String, status: Int = 200, headers: [String: String] = [:]) {
        self.body = body
        self.status = status
        self.headers = headers
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!)
    }

    func captured() -> [URLRequest] { requests }
}

func makeAPI(_ transport: any HTTPTransport) throws -> NHentaiAPI {
    NHentaiAPI(client: APIClient(key: try APIKey("test-only-key"), transport: transport))
}

let minimalUser = #"{"id":1,"username":"reader","slug":"reader","avatar_url":"https://example.com/avatar.png"}"#
let emptyPage = #"{"result":[],"num_pages":0}"#

@Test func authenticationUsesKeyHeaderAndDecodesOmittedDefaults() async throws {
    let transport = StubTransport(minimalUser)
    let user = try await makeAPI(transport).currentUser()
    #expect(user.username == "reader")
    #expect(user.about == "")
    let request = try #require(await transport.captured().first)
    #expect(request.url?.path == "/api/v2/user")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Key test-only-key")
    #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("NHV/") == true)
}

@Test func searchPreservesSyntaxAndUsesOnlySupportedParameters() async throws {
    let transport = StubTransport(emptyPage)
    let query = #"artist:"some name" -language:japanese pages:>10 & + 中文"#
    _ = try await makeAPI(transport).search(query: query, sort: .week, page: 2)
    let request = try #require(await transport.captured().first)
    let items = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems)
    #expect(items.first(where: { $0.name == "query" })?.value == query)
    #expect(items.first(where: { $0.name == "sort" })?.value == "popular-week")
    #expect(items.first(where: { $0.name == "page" })?.value == "2")
    #expect(!items.contains(where: { $0.name == "per_page" }))
    #expect(request.url?.query?.contains("%2B") == true)
    #expect(request.url?.query?.contains("+") == false)
}

@Test func listModelDoesNotInventFavoriteStatus() async throws {
    let transport = StubTransport(#"{"result":[{"id":1,"media_id":"2","english_title":"Fixture","thumbnail":"/galleries/2/thumb.webp","thumbnail_width":200,"thumbnail_height":300}],"num_pages":1}"#)
    let page = try await makeAPI(transport).galleries()
    let item = try #require(page.result.first)
    #expect(item.numPages == 0)
    #expect(item.tagIds.isEmpty)
    #expect(page.total == nil)
}

@Test func detailRequestsFavoriteOnlyAndIgnoresUnrelatedFields() async throws {
    let transport = StubTransport(#"{"id":1,"media_id":"2","title":{"english":"Fixture","pretty":"Fixture"},"cover":{"path":"/cover.webp","width":20,"height":30},"thumbnail":{"path":"/thumb.webp","width":2,"height":3},"upload_date":123,"tags":[],"num_pages":0,"num_favorites":5,"comments":{"unmodeled":true}}"#)
    let detail = try await makeAPI(transport).gallery(id: 1)
    #expect(detail.isFavorited == nil)
    #expect(detail.pages.isEmpty)
    let request = try #require(await transport.captured().first)
    #expect(request.url?.query == "include=favorite")
}

@Test func relatedGalleriesUsesDocumentedEndpointAndDecodesListItems() async throws {
    let transport = StubTransport(#"{"result":[{"id":42,"media_id":"2","english_title":"Related fixture","thumbnail":"/galleries/2/thumb.webp","thumbnail_width":200,"thumbnail_height":300,"num_pages":12,"num_favorites":34}]}"#)
    let result = try await makeAPI(transport).relatedGalleries(id: 7)
    let item = try #require(result.first)
    #expect(item.id == 42)
    #expect(item.englishTitle == "Related fixture")
    #expect(item.numPages == 12)
    #expect(item.numFavorites == 34)
    let request = try #require(await transport.captured().first)
    #expect(request.url?.path == "/api/v2/galleries/7/related")
    #expect(request.url?.query == nil)
}

@Test func favoriteWritesUseExplicitMethods() async throws {
    let transport = StubTransport(#"{"favorited":true,"num_favorites":8}"#)
    let api = try makeAPI(transport)
    let response = try await api.setFavorite(id: 42, favorited: true)
    _ = try await api.setFavorite(id: 42, favorited: false)
    let requests = await transport.captured()
    #expect(requests.map(\.httpMethod) == ["POST", "DELETE"])
    #expect(requests.allSatisfy { $0.url?.path == "/api/v2/galleries/42/favorite" })
    #expect(response.numFavorites == 8)
}

@Test func rateLimitedWritesAreNotAutomaticallyRepeated() async throws {
    let transport = StubTransport(#"{"error":"slow down"}"#, status: 429, headers: ["Retry-After": "12"])
    await #expect(throws: APIError.rateLimited(retryAfter: 12)) {
        _ = try await makeAPI(transport).setFavorite(id: 1, favorited: true)
    }
    #expect(await transport.captured().count == 1)
}

@Test(arguments: [401, 403, 404, 500]) func errorsAreClassified(status: Int) async throws {
    let transport = StubTransport("{}", status: status)
    let expected: APIError = switch status {
    case 401: .unauthenticated
    case 403: .forbidden
    case 404: .notFound
    default: .server(status: status)
    }
    await #expect(throws: expected) { _ = try await makeAPI(transport).currentUser() }
}

@Test func invalidInputsDoNotMakeRequests() async throws {
    let transport = StubTransport(emptyPage)
    let api = try makeAPI(transport)
    await #expect(throws: APIError.self) { _ = try await api.galleries(page: 0) }
    await #expect(throws: APIError.self) { _ = try await api.galleries(perPage: 101) }
    await #expect(throws: APIError.self) { _ = try await api.search(query: "  ") }
    #expect(await transport.captured().isEmpty)
    #expect(throws: APIError.self) { try APIKey("bad\r\nkey") }
    #expect(String(reflecting: try APIKey("secret")) == "<APIKey redacted>")
}

@Test func tagAutocompleteSendsJSONBody() async throws {
    let transport = StubTransport("[]")
    _ = try await makeAPI(transport).searchTags(query: "some name", type: .artist)
    let request = try #require(await transport.captured().first)
    #expect(request.httpMethod == "POST")
    let body = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
    #expect(body["query"] as? String == "some name")
    #expect(body["type"] as? String == "artist")
    #expect(body["limit"] as? Int == 10)
}

@Test func cdnUsesReturnedPathsAndDoesNotReceiveCredentials() async throws {
    let transport = StubTransport(#"{"image_servers":["https://images.example.com/"],"thumb_servers":["https://thumbs.example.com"]}"#)
    let config = try await makeAPI(transport).cdnConfiguration()
    let request = try #require(await transport.captured().first)
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    let resolver = CDNResolver(configuration: config)
    #expect(try resolver.url(for: "/galleries/2/003.avif", kind: .image).absoluteString == "https://images.example.com/galleries/2/003.avif")
    #expect(try resolver.url(for: "galleries/2/thumb.webp", kind: .thumbnail).host == "thumbs.example.com")
    #expect(throws: APIError.self) { try resolver.url(for: "https://elsewhere.example/image.jpg", kind: .image) }
}

@Test func cancellationRemainsCancellation() async throws {
    struct CancelledTransport: HTTPTransport {
        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            throw URLError(.cancelled)
        }
    }
    await #expect(throws: CancellationError.self) { _ = try await makeAPI(CancelledTransport()).currentUser() }
}
