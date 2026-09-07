import SwiftUI
import NHVCore

@main
struct NHVApp: App {
    @State private var session = SessionStore(credentials: KeychainCredentialStore())
    @State private var language = LanguagePreference()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(language)
                .environment(\.locale, language.locale)
        }
    }
}
