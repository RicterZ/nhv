import Foundation
import Testing
@testable import NHVCore

@MainActor final class MemoryCredentials: CredentialStore {
    var key: APIKey?
    var saveError: CredentialError?
    var deleteError: CredentialError?

    init(_ key: APIKey? = nil) { self.key = key }
    func load() throws -> APIKey? { key }
    func save(_ key: APIKey) throws {
        if let saveError { throw saveError }
        self.key = key
    }
    func delete() throws {
        if let deleteError { throw deleteError }
        key = nil
    }
}

@MainActor func makeSession(_ credentials: MemoryCredentials, transport: any HTTPTransport) -> SessionStore {
    SessionStore(credentials: credentials) { key in
        NHentaiAPI(client: APIClient(key: key, transport: transport))
    }
}

@Test @MainActor func firstLaunchDoesNotSendAnonymousLoginRequests() async {
    let transport = StubTransport(minimalUser)
    let store = makeSession(MemoryCredentials(), transport: transport)
    await store.restore()
    guard case .signedOut = store.phase else { Issue.record("Expected sign in"); return }
    #expect(await transport.captured().isEmpty)
}

@Test @MainActor func successfulSignInPersistsOnlyValidatedKey() async throws {
    let credentials = MemoryCredentials()
    let store = makeSession(credentials, transport: StubTransport(minimalUser))
    await store.restore()
    await store.signIn(key: "  test-only-key  ")
    guard case .authenticated(let account) = store.phase else { Issue.record("Expected authenticated session"); return }
    #expect(account.user.id == 1)
    #expect(credentials.key?.value == "test-only-key")
    #expect(!store.isBusy)
    store.signOut()
    #expect(credentials.key == nil)
    guard case .signedOut = store.phase else { Issue.record("Expected sign out"); return }
}

@Test @MainActor func failedSignInDoesNotSaveKey() async {
    let credentials = MemoryCredentials()
    let store = makeSession(credentials, transport: StubTransport("{}", status: 401))
    await store.restore()
    await store.signIn(key: "invalid-key")
    #expect(credentials.key == nil)
    #expect(store.error as? APIError == .unauthenticated)
    guard case .signedOut = store.phase else { Issue.record("Expected sign in"); return }
}

@Test @MainActor func restoreFailurePreservesKeyAndAllowsRetry() async throws {
    let credentials = MemoryCredentials(try APIKey("test-key"))
    let transport = StubTransport("{}", status: 500)
    let store = makeSession(credentials, transport: transport)
    await store.restore()
    guard case .restoreFailed = store.phase else { Issue.record("Expected recoverable failure"); return }
    #expect(credentials.key != nil)
    await store.restore()
    #expect(await transport.captured().count == 2)
}

@Test @MainActor func invalidSavedKeyIsRemoved() async throws {
    let credentials = MemoryCredentials(try APIKey("expired-key"))
    let store = makeSession(credentials, transport: StubTransport("{}", status: 401))
    await store.restore()
    #expect(credentials.key == nil)
    guard case .signedOut = store.phase else { Issue.record("Expected sign in"); return }
}

@Test @MainActor func forbiddenResponseDoesNotEraseSavedKey() async throws {
    let credentials = MemoryCredentials(try APIKey("test-key"))
    let store = makeSession(credentials, transport: StubTransport("{}", status: 403))
    await store.restore()
    #expect(credentials.key != nil)
    #expect(store.error as? APIError == .forbidden)
}

@Test @MainActor func keychainWriteFailureDoesNotEnterApp() async {
    let credentials = MemoryCredentials()
    credentials.saveError = .status(-1)
    let store = makeSession(credentials, transport: StubTransport(minimalUser))
    await store.restore()
    await store.signIn(key: "test-key")
    #expect(store.error as? CredentialError == .status(-1))
    guard case .signedOut = store.phase else { Issue.record("Expected failed sign in"); return }
}

@Test @MainActor func keychainDeleteFailureDoesNotPretendToSignOut() async throws {
    let credentials = MemoryCredentials(try APIKey("test-key"))
    let store = makeSession(credentials, transport: StubTransport(minimalUser))
    await store.restore()
    credentials.deleteError = .status(-1)
    store.signOut()
    #expect(store.error as? CredentialError == .status(-1))
    guard case .authenticated = store.phase else { Issue.record("Session must remain until deletion succeeds"); return }
}

actor SuspendedTransport: HTTPTransport {
    private var continuation: CheckedContinuation<Void, Never>?
    private var ready: CheckedContinuation<Void, Never>?
    private var started = false

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started = true
            ready?.resume()
            ready = nil
        }
        return (Data(minimalUser.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { ready = $0 }
    }

    func resume() { continuation?.resume(); continuation = nil }
}

@Test @MainActor func signOutDuringRestoreDiscardsLateResponse() async throws {
    let credentials = MemoryCredentials(try APIKey("test-key"))
    let transport = SuspendedTransport()
    let store = makeSession(credentials, transport: transport)
    let task = Task { await store.restore() }
    await transport.waitUntilStarted()
    store.signOut()
    await transport.resume()
    await task.value
    #expect(credentials.key == nil)
    #expect(!store.isBusy)
    guard case .signedOut = store.phase else { Issue.record("Late response restored a signed-out session"); return }
}
