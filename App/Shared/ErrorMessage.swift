import Foundation
import NHVCore

enum ErrorMessage {
    static func text(for error: any Error) -> String {
        if error is CredentialError {
            return String(localized: "Unable to access your saved API key. Please try again.")
        }
        guard let error = error as? APIError else {
            return String(localized: "Something went wrong. Please try again.")
        }
        switch error {
        case .invalidInput(let issue):
            switch issue {
            case .apiKey: return String(localized: "Enter your API key without the Key prefix or any spaces.")
            case .emptySearch: return String(localized: "Enter a search query.")
            case .page: return String(localized: "Page numbers must start at 1.")
            case .pageSize: return String(localized: "Page size must be between 1 and 100.")
            case .identifier: return String(localized: "The content ID must be greater than zero.")
            case .tagSlug: return String(localized: "The tag address cannot be empty.")
            case .tagLimit: return String(localized: "Tag result count must be between 1 and 50.")
            case .url: return String(localized: "The request address is invalid.")
            }
        case .unauthenticated: return String(localized: "Your API key is invalid or has expired. Enter it again.")
        case .forbidden: return String(localized: "Access is denied or this feature is currently unavailable.")
        case .notFound: return String(localized: "This content was not found or has been removed.")
        case .rateLimited: return String(localized: "Too many requests. Please try again later.")
        case .server(let status): return String(localized: "Request failed (HTTP \(status)). Please try again.")
        case .invalidResponse: return String(localized: "The server returned an invalid response.")
        case .decoding: return String(localized: "This response format is not supported by this version of the app.")
        case .transport: return String(localized: "Unable to connect. Check your connection and try again.")
        }
    }
}
