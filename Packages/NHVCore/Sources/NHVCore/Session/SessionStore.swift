import Foundation
import Observation
import CryptoKit

public struct AuthenticatedSession: Sendable, Identifiable {
    public let id: UUID
    public let user: CurrentUser
    public let api: NHentaiAPI
}

@Observable @MainActor
public final class SessionStore {
    public enum Phase {
        case restoring
        case signedOut
        case authenticated(AuthenticatedSession)
        case restoreFailed
    }

    public private(set) var phase: Phase = .restoring
    public private(set) var restoredFromCache = false
    @ObservationIgnored private let defaults: UserDefaults?
    private struct SavedAccount: Codable { let fingerprint: String; let user: CurrentUser }
    private static let cacheKey = "session.savedAccount"
    public private(set) var isBusy = false
    public private(set) var error: (any Error)?
    @ObservationIgnored private let credentials: any CredentialStore
    @ObservationIgnored private let makeAPI: @Sendable (APIKey) -> NHentaiAPI
    @ObservationIgnored private var generation = UUID()

    public init(
        credentials: any CredentialStore,
        defaults: UserDefaults? = nil,
        makeAPI: @escaping @Sendable (APIKey) -> NHentaiAPI = { NHentaiAPI(client: APIClient(key: $0)) }
    ) {
        self.defaults = defaults
        self.credentials = credentials
        self.makeAPI = makeAPI
        if let key = try? credentials.load(), let data = defaults?.data(forKey: Self.cacheKey),
           let saved = try? JSONDecoder().decode(SavedAccount.self, from: data),
           saved.fingerprint == Self.fingerprint(key) {
            phase = .authenticated(.init(id: UUID(), user: saved.user, api: sessionAPI(key)))
            restoredFromCache = true
        }
    }

    public func restore() async {
        guard !isBusy else { return }
        if case .authenticated = phase { await validate(); return }
        switch phase {
        case .restoring, .restoreFailed: break
        default: return
        }
        error = nil
        do {
            guard let key = try credentials.load() else {
                phase = .signedOut
                return
            }
            phase = .restoring
            await authenticate(key, restoring: true)
        } catch {
            self.error = error
            phase = .restoreFailed
        }
    }

    public func signIn(key value: String) async {
        guard !isBusy, case .signedOut = phase else { return }
        error = nil
        do {
            await authenticate(try APIKey(value), restoring: false)
        } catch {
            self.error = error
        }
    }

    public func signOut() {
        do {
            try credentials.delete()
            // Invalidate in-flight work before dropping all account-scoped state.
            defaults?.removeObject(forKey: Self.cacheKey)
            restoredFromCache = false
            generation = UUID()
            isBusy = false
            error = nil
            phase = .signedOut
        } catch {
            self.error = error
        }
    }

    private static func fingerprint(_ key: APIKey) -> String {
        SHA256.hash(data: Data(key.value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func save(_ user: CurrentUser, key: APIKey) {
        if let data = try? JSONEncoder().encode(SavedAccount(fingerprint: Self.fingerprint(key), user: user)) {
            defaults?.set(data, forKey: Self.cacheKey)
        }
    }

    private func sessionAPI(_ key: APIKey) -> NHentaiAPI {
        let operation = generation
        return makeAPI(key).handlingUnauthorized { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.generation == operation,
                      case .authenticated = self.phase else { return }
                self.invalidateKey()
            }
        }
    }

    private func invalidateKey() {
        generation = UUID()
        defaults?.removeObject(forKey: Self.cacheKey)
        try? credentials.delete()
        restoredFromCache = false
        isBusy = false
        error = APIError.unauthenticated
        phase = .signedOut
    }

    /// Transient network/permission errors never hide a restored page.
    public func validate() async {
        guard !isBusy, case .authenticated(let account) = phase else { return }
        let operation = generation
        isBusy = true
        defer { if generation == operation { isBusy = false } }
        do {
            let user = try await account.api.currentUser()
            try Task.checkCancellation()
            guard generation == operation else { return }
            guard user.id == account.user.id else { invalidateKey(); return }
            if let key = try credentials.load() { save(user, key: key) }
            error = nil
        } catch is CancellationError {} catch {
            guard generation == operation else { return }
            if error as? APIError == .unauthenticated { invalidateKey() }
            else { self.error = error }
        }
    }

    private func authenticate(_ key: APIKey, restoring: Bool) async {
        isBusy = true
        let operation = UUID()
        generation = operation
        defer { if generation == operation { isBusy = false } }
        do {
            let api = sessionAPI(key)
            let user = try await api.currentUser()
            try Task.checkCancellation()
            guard generation == operation else { return }
            if !restoring { try credentials.save(key) }
            save(user, key: key)
            phase = .authenticated(.init(id: UUID(), user: user, api: api))
        } catch is CancellationError {
            guard generation == operation else { return }
            phase = restoring ? .restoreFailed : .signedOut
        } catch {
            guard generation == operation else { return }
            self.error = error
            if restoring, error as? APIError == .unauthenticated {
                do {
                    try credentials.delete()
                    phase = .signedOut
                } catch {
                    self.error = error
                    phase = .restoreFailed
                }
            } else {
                // Connectivity and permission failures never erase saved credentials.
                phase = restoring ? .restoreFailed : .signedOut
            }
        }
    }
}
