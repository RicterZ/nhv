import Foundation

public struct APIClient: Sendable {
    private let key: APIKey
    private let transport: any HTTPTransport

    public init(key: APIKey, transport: any HTTPTransport = URLSessionTransport()) {
        self.key = key
        self.transport = transport
    }

    func send<Response: Decodable & Sendable>(
        _ path: [String], method: String = "GET", query: [URLQueryItem] = [],
        body: Data? = nil, authenticated: Bool = true
    ) async throws -> Response {
        try Task.checkCancellation()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let encodedPath = path.map { $0.addingPercentEncoding(withAllowedCharacters: allowed)! }.joined(separator: "/")
        var components = URLComponents(url: AppConfiguration.apiBaseURL, resolvingAgainstBaseURL: false)!
        components.percentEncodedPath = "/api/v2/" + encodedPath
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw APIError.invalidInput(.url) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
        if authenticated { request.setValue("Key \(key.value)", forHTTPHeaderField: "Authorization") }
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport
        }
        try Task.checkCancellation()
        switch response.statusCode {
        case 200..<300: break
        case 401: throw APIError.unauthenticated
        case 403: throw APIError.forbidden
        case 404: throw APIError.notFound
        case 429: throw APIError.rateLimited(retryAfter: Self.retryDelay(response.value(forHTTPHeaderField: "Retry-After")))
        default: throw APIError.server(status: response.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private static func retryDelay(_ header: String?) -> TimeInterval? {
        guard let header else { return nil }
        if let seconds = TimeInterval(header), seconds.isFinite { return max(0, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter.date(from: header).map { max(0, $0.timeIntervalSinceNow) }
    }
}
