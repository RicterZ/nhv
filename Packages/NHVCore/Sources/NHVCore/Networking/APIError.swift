import Foundation

public enum InputIssue: Sendable, Equatable {
    case apiKey, url, emptySearch, page, pageSize, identifier, tagSlug, tagLimit
}

public enum APIError: Error, Sendable, Equatable {
    case invalidInput(InputIssue)
    case unauthenticated
    case forbidden
    case notFound
    case rateLimited(retryAfter: TimeInterval?)
    case server(status: Int)
    case invalidResponse
    case decoding
    case transport

}

public struct APIKey: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let value: String

    public init(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace || $0.isNewline }),
              !trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw APIError.invalidInput(.apiKey)
        }
        self.value = trimmed
    }

    public var description: String { "<APIKey redacted>" }
    public var debugDescription: String { description }
}
