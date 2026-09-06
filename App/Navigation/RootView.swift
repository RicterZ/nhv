import NHVCore
import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session
    @State private var readyAccountID: UUID?
    @State private var presentation = LoginPresentation()

    private var isReady: Bool {
        if case .authenticated(let account) = session.phase { return readyAccountID == account.id }
        return false
    }

    var body: some View {
        ZStack {
            if case .authenticated(let account) = session.phase {
                MainTabView(account: account)
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
                if showsSignIn {
                    SignInView()
                } else {
                    ContentUnavailableView {
                        Label("Unable to restore session", systemImage: "wifi.exclamationmark")
                    } description: {
                        if let error = session.error {
                            Text(ErrorMessage.text(for: error))
                        }
                    } actions: {
                        Button("Try Again") { Task { await restore() } }
                            .buttonStyle(.borderedProminent)
                        Button("Use Another API Key") { session.signOut() }
                    }
                }
            }
        }
        .environment(presentation)
        .onChange(of: isReady) { _, ready in
            if !ready { readyAccountID = nil }
        }
        .task { await restore() }
    }

    private var showsSignIn: Bool {
        if case .restoreFailed = session.phase { return presentation.isActive }
        return true
    }

    private func restore() async {
        presentation.begin()
        await session.restore()
        if case .authenticated = session.phase { return }
        try? await presentation.finish()
    }
}
