import SwiftUI
import NHVCore

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(MediaStore.self) private var media
    @State private var showsCacheCleared = false
    let user: CurrentUser

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("Username", value: user.username)
                if !user.about.isEmpty { Text(verbatim: user.about) }
            }
            Section {
                Button {
                    Task {
                        await media.thumbnails.clearCache()
                        showsCacheCleared = true
                    }
                } label: {
                    HStack {
                        Label("Clear Cache", systemImage: "trash")
                        Spacer()
                        if media.thumbnails.isClearingCache { ProgressView() }
                    }
                }
                .disabled(media.thumbnails.isClearingCache)
            }
            Section {
                Button("Sign Out", role: .destructive) { session.signOut() }
                if let error = session.error { InlineErrorView(error: error) }
            } header: {
                Color.clear
                    .frame(height: 16)
                    .accessibilityHidden(true)
            }
        }
        .listSectionSpacing(12)
        .navigationTitle("Me")
        .alert("Cache Cleared", isPresented: $showsCacheCleared) {
            Button("OK", role: .cancel) {}
        }
    }
}
