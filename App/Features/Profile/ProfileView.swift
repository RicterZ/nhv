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
                Button("Sign Out", role: .destructive) { session.signOut() }
                if let error = session.error { InlineErrorView(error: error) }
            }
            Section {
                Picker("Appearance", selection: $theme) {
                    Text("Dark").tag(AppTheme.dark)
                    Text("Light").tag(AppTheme.light)
                }
                .tint(theme.accentColor)
                .id("appearance-\(theme.rawValue)")
                Picker("Language", selection: $language.selection) {
                    ForEach(AppLanguage.allCases, id: \.self) { option in
                        Text(verbatim: option.definition.nativeName).tag(option)
                    }
                }
                .tint(theme.accentColor)
                .id("language-\(theme.rawValue)")
                Toggle("Filter by App Language", isOn: $language.filterGalleries)
            } header: {
                Text("Settings")
            } footer: {
                Text("Show only galleries in the selected language on Home and Search.")
            }
            Section {
                Button(role: .destructive) {
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
            Section("About") {
                LabeledContent("Version", value: appVersion)
                Link(destination: URL(string: "https://github.com/RicterZ/nhv")!) {
                    HStack {
                        Text(verbatim: "GitHub")
                        Spacer()
                        Text(verbatim: "RicterZ/nhv")
                            .foregroundStyle(theme.accentColor)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .listSectionSpacing(12)
        .navigationTitle("Settings")
        .alert("Cache Cleared", isPresented: $showsCacheCleared) {
            Button("OK", role: .cancel) {}
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
