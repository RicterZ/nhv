import SwiftUI
import NHVCore

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(MediaStore.self) private var media
    @Environment(LanguagePreference.self) private var language
    @State private var showsCacheCleared = false
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark
    let user: CurrentUser

    var body: some View {
        @Bindable var language = language
        List {
            Section("Account") {
                LabeledContent("Username", value: user.username)
                if !user.about.isEmpty { Text(verbatim: user.about) }
            }
            Section {
                Picker("Appearance", selection: $theme) {
                    Text("Dark").tag(AppTheme.dark)
                    Text("Light").tag(AppTheme.light)
                }
                Picker("Language", selection: $language.selection) {
                    ForEach(AppLanguage.allCases, id: \.self) { option in
                        Text(verbatim: option.definition.nativeName).tag(option)
                    }
                }
                Toggle("Filter by App Language", isOn: $language.filterGalleries)
            } footer: {
                Text("Show only galleries in the selected language on Home and Search.")
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
        .navigationTitle("Settings")
        .alert("Cache Cleared", isPresented: $showsCacheCleared) {
            Button("OK", role: .cancel) {}
        }
    }
}
