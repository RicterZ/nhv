import SwiftUI
import NHVCore

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    let user: CurrentUser

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("Username", value: user.username)
                if !user.about.isEmpty { Text(verbatim: user.about) }
            }
            Section {
                Button("Sign Out", role: .destructive) { session.signOut() }
                if let error = session.error { InlineErrorView(error: error) }
            }
        }
        .navigationTitle("Me")
    }
}
