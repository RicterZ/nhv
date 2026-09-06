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
                    .foregroundStyle(.red)
                }
                .disabled(media.thumbnails.isClearingCache)
            }
            Section {
                LabeledContent("Version", value: appVersion)
                LabeledContent {
                    Text(verbatim: "MIT")
                } label: {
                    Text(verbatim: "License")
                }
                Link(destination: URL(string: "https://github.com/RicterZ/nhv")!) {
                    HStack {
                        Text(verbatim: "GitHub")
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Text(verbatim: "RicterZ/nhv")
                            .foregroundStyle(theme.accentColor)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(theme.accentColor)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("About")
            } footer: {
                VStack(alignment: .leading, spacing: 12) {
                    Text(verbatim: "本项目为独立、非官方的开源客户端，与 nhentai 及其运营方不存在隶属、合作或背书关系，仅供学习、研究与个人使用。第三方内容及其版权归相应权利人所有，本项目不拥有或提供这些内容，也不参与用户、平台与版权方之间的争议。使用者应自行确认访问权限，遵守所在国家或地区的法律法规、年龄限制及平台服务条款，尊重知识产权，不得用于违法或侵权活动。软件按原样提供，不作任何保证；责任限制以 MIT 许可证及适用法律为准。本声明不免除任何依法应承担的责任。")
                    Text(verbatim: "This is an independent, unofficial open-source client with no affiliation, partnership, or endorsement from nhentai or its operators. It is intended solely for learning, research, and personal use. Third-party content and copyrights belong to their respective rights holders. This project neither owns nor supplies that content and is not a party to disputes between users, platforms, and rights holders. Users must verify their right to access content, comply with the laws, age restrictions, and platform terms applicable in their country or region, and respect intellectual property rights. Unlawful or infringing use is prohibited. The software is provided as is, without warranty; limitations of liability are subject to the MIT License and applicable law. This notice does not exclude any liability that cannot lawfully be excluded.")
                }
                .textCase(nil)
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
