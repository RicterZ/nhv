import NHVCore
import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var readyAccountID: UUID?
    @State private var presentation = LoginPresentation()
    @State private var isReturningToLogin = false
    @State private var submittedKey: String?

    private var isReady: Bool {
        if case .authenticated(let account) = session.phase { return readyAccountID == account.id }
        return false
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if case .authenticated(let account) = session.phase {
                MainTabView(account: account, isReady: isReady)
                    .id(account.id)
                    .opacity(isReady ? 1 : 0)
                    .allowsHitTesting(isReady)
                    .accessibilityHidden(!isReady)
                    .task(id: account.id) {
                        // Mount the real home feed so its requests and image queue are reused.
                        do { try await presentation.finish() } catch { return }
                        guard case .authenticated(let current) = session.phase, current.id == account.id else { return }
                        readyAccountID = account.id
                    }
            }
            if !isReady {
                ZStack {
                    if showsSignIn {
                        SignInView(submit: signIn)
                    } else {
                        SessionErrorView(
                            error: session.error,
                            retry: {
                                presentation.begin(reduceMotion: reduceMotion)
                                isReturningToLogin = true
                            },
                            useAnotherKey: {
                                submittedKey = nil
                                session.signOut()
                            }
                        )
                        .opacity(isReturningToLogin ? 0 : 1)
                        .allowsHitTesting(!isReturningToLogin)
                        .accessibilityHidden(isReturningToLogin)
                        .animation(.easeOut(duration: 0.2), value: isReturningToLogin)
                    }
                }
                .animation(.easeOut(duration: 0.25), value: showsSignIn)
            }
        }
        .overlay {
            if !isReady {
                SessionLogoView(showsError: !showsSignIn && !isReturningToLogin)
            }
        }
        .environment(presentation)
        .onChange(of: isReady) { _, ready in
            if ready { submittedKey = nil }
            else { readyAccountID = nil }
        }
        .task {
            await restore()
        }
        .task(id: isReturningToLogin) {
            guard isReturningToLogin else { return }
            do {
                // Finish the return journey before starting the bounce cycle.
                try await Task.sleep(for: .seconds(reduceMotion ? 0.2 : LoginPresentation.travelDuration))
            } catch {
                isReturningToLogin = false
                return
            }
            if let submittedKey {
                await session.signIn(key: submittedKey)
                if case .authenticated = session.phase {} else { try? await presentation.finish() }
            } else {
                await restore(beginAnimation: false)
            }
            isReturningToLogin = false
        }
    }

    private var showsSignIn: Bool {
        if case .restoreFailed = session.phase { return presentation.isActive }
        if case .signedOut = session.phase, session.error != nil { return presentation.isActive }
        return true
    }

    private func signIn(_ key: String) {
        submittedKey = key
        presentation.begin(reduceMotion: reduceMotion, fromInput: true)
        Task {
            await session.signIn(key: key)
            if case .authenticated = session.phase { return }
            try? await presentation.finish()
        }
    }

    private func restore(beginAnimation: Bool = true) async {
        if beginAnimation { presentation.begin(reduceMotion: reduceMotion, fromInput: true) }
        await session.restore()
        if case .authenticated = session.phase { return }
        try? await presentation.finish()
    }
}
