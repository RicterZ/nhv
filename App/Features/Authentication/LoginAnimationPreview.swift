import Foundation
import NHVCore

/// Temporary acceptance flow. Disable after reviewing the login transitions.
@MainActor
enum LoginAnimationPreview {
    #if DEBUG
    static let enabled = true
    #else
    static let enabled = false
    #endif

    static func makeSession() -> SessionStore {
        #if DEBUG
        if enabled {
            return SessionStore(credentials: PreviewCredentials()) { key in
                NHentaiAPI(client: APIClient(key: key, transport: FailingTransport()))
            }
        }
        #endif
        return SessionStore(credentials: KeychainCredentialStore())
    }
}

#if DEBUG
private struct PreviewCredentials: CredentialStore {
    func load() throws -> APIKey? { nil }
    func save(_ key: APIKey) throws {}
    func delete() throws {}
}

private struct FailingTransport: HTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await Task.sleep(for: .seconds(3))
        throw APIError.transport
    }
}
#endif
