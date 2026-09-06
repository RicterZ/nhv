import SwiftUI
import NHVCore

enum ErrorMessage {
    static func text(for error: any Error) -> LocalizedStringKey {
        if error is CredentialError {
            return "Unable to access your saved API key. Please try again."
        }
        guard let error = error as? APIError else {
            return "Something went wrong. Please try again."
        }
        switch error {
        case .invalidInput(let issue):
            switch issue {
            case .apiKey: return "Enter your API key without the Key prefix or any spaces."
            case .emptySearch: return "Enter a search query."
            case .page: return "Page numbers must start at 1."
            case .pageSize: return "Page size must be between 1 and 100."
            case .identifier: return "The content ID must be greater than zero."
            case .tagSlug: return "The tag address cannot be empty."
            case .tagLimit: return "Tag result count must be between 1 and 50."
            case .url: return "The request address is invalid."
            }
        case .unauthenticated: return "Your API key is invalid or has expired. Enter it again."
        case .forbidden: return "Access is denied or this feature is currently unavailable."
        case .notFound: return "This content was not found or has been removed."
        case .rateLimited: return "Too many requests. Please try again later."
        case .server(let status): return "Request failed (HTTP \(status)). Please try again."
        case .invalidResponse: return "The server returned an invalid response."
        case .decoding: return "This response format is not supported by this version of the app."
        case .transport: return "Unable to connect. Check your connection and try again."
        }
    }
}
