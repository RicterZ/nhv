import SwiftUI
import NHVCore

struct RootView: View {
    @Environment(SessionStore.self) private var session
    @State private var readyAccountID: UUID?

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
                        do { try await Task.sleep(for: LoginPresentation.minimumDuration) }
                        catch { return }
                        guard case .authenticated(let current) = session.phase, current.id == account.id else { return }
                        readyAccountID = account.id
                    }
            }
            switch session.phase {
            case .restoring, .signedOut, .authenticated:
                if !isReady { SignInView() }
            case .restoreFailed:
                ContentUnavailableView {
                    Label("Unable to restore session", systemImage: "wifi.exclamationmark")
                } description: {
                    if let error = session.error {
                        Text(ErrorMessage.text(for: error))
                    }
                } actions: {
                    Button("Try Again") { Task { await session.restore() } }
                        .buttonStyle(.borderedProminent)
                    Button("Use Another API Key") { session.signOut() }
                }
            }
        }
        .onChange(of: isReady) { _, ready in
            if !ready { readyAccountID = nil }
        }
        .task { await session.restore() }
    }
}
