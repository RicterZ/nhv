import Foundation
import Observation

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
    public private(set) var isBusy = false
    public private(set) var error: (any Error)?
    @ObservationIgnored private let credentials: any CredentialStore
    @ObservationIgnored private let makeAPI: @Sendable (APIKey) -> NHentaiAPI
    @ObservationIgnored private var generation = UUID()

    public init(
        credentials: any CredentialStore,
        makeAPI: @escaping @Sendable (APIKey) -> NHentaiAPI = { NHentaiAPI(client: APIClient(key: $0)) }
    ) {
        self.credentials = credentials
        self.makeAPI = makeAPI
    }

    public func restore() async {
        guard !isBusy else { return }
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
            generation = UUID()
            isBusy = false
            error = nil
            phase = .signedOut
        } catch {
            self.error = error
        }
    }

    private func authenticate(_ key: APIKey, restoring: Bool) async {
        isBusy = true
        let operation = UUID()
        generation = operation
        defer { if generation == operation { isBusy = false } }
        do {
            let api = makeAPI(key)
            let user = try await api.currentUser()
            try Task.checkCancellation()
            guard generation == operation else { return }
            if !restoring { try credentials.save(key) }
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
