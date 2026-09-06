import SwiftUI
import NHVCore

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            switch session.phase {
            case .restoring:
                ProgressView("Restoring session…")
            case .signedOut:
                SignInView()
            case .authenticated(let account):
                MainTabView(account: account)
                    .id(account.id)
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
        .task { await session.restore() }
    }
}
