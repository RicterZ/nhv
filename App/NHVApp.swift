import SwiftUI
import NHVCore

@main
struct NHVApp: App {
    @State private var session = SessionStore(credentials: KeychainCredentialStore())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
    }
}
