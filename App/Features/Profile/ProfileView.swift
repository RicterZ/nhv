import SwiftUI
import NHVCore

struct ProfileView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(SessionStore.self) private var session
    @Environment(MediaStore.self) private var media
    @Environment(LanguagePreference.self) private var language
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var cacheSize: Int64?
    @State private var isLoadingCacheSize = true
    @State private var historyCount: Int?
    @State private var showsCacheCleared = false
    @State private var cacheError: (any Error)?
    @State private var showsCacheError = false
    @State private var showsClearCacheConfirmation = false
    @State private var showsSignOutConfirmation = false
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark
    @AppStorage(ContentDisplayPreference.nsfwKey) private var nsfwEnabled = true
    @AppStorage(ContentDisplayPreference.relatedKey) private var showsRelatedGalleries = true
    @AppStorage(ContentDisplayPreference.galleryColumnsKey) private var galleryColumns = 2
    @AppStorage(PageTurnMode.storageKey) private var pageTurnMode = PageTurnMode.tap
    @AppStorage(PageTurnMode.doubleTapZoomKey) private var doubleTapZoom = false
    @AppStorage(ClipboardGallery.enabledKey) private var readsClipboard = true
    let user: CurrentUser
    let api: NHentaiAPI

    var body: some View {
        @Bindable var language = language
        List {
            Section("Account") {
                LabeledContent("Username", value: user.username)
                Button("Sign Out", role: .destructive) { showsSignOutConfirmation = true }
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
                Toggle(isOn: $language.filterGalleries) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Language Filter")
                        Text("Show only galleries in the selected language on Home and Search.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Picker("Gallery Columns", selection: $galleryColumns) {
                    Text("2 Columns").tag(2)
                    Text("3 Columns").tag(3)
                }
                .tint(theme.accentColor)
                .id("gallery-columns-\(theme.rawValue)")
                Picker("Page Turn Method", selection: $pageTurnMode) {
                    Text("Tap Left or Right").tag(PageTurnMode.tap)
                    Text("Swipe Left or Right").tag(PageTurnMode.swipe)
                }
                .tint(theme.accentColor)
                .id("page-turn-\(theme.rawValue)")
                Toggle("Double-Tap to Zoom", isOn: Binding(
                    get: { pageTurnMode == .swipe && doubleTapZoom },
                    set: { doubleTapZoom = $0 }
                ))
                .disabled(pageTurnMode != .swipe)
                Toggle("Read Clipboard", isOn: $readsClipboard)
                Toggle("Show Related Content", isOn: $showsRelatedGalleries)
                Toggle(isOn: $nsfwEnabled) {
                    Text(verbatim: "NSFW")
                }
            } header: {
                Text("Settings")
            }
            Section {
                LabeledContent("Cache Size") {
                    if isLoadingCacheSize {
                        ProgressView()
                    } else if let cacheSize {
                        Text(cacheSize, format: .byteCount(style: .file).locale(locale))
                    } else {
                        Text("Unavailable")
                    }
                }
                NavigationLink(value: AppNavigation.Route(.history)) {
                    LabeledContent("Browsing History") {
                        if let historyCount {
                            Text(historyCount, format: .number)
                        } else {
                            Text("—")
                        }
                    }
                }
                Button(role: .destructive) {
                    showsClearCacheConfirmation = true
                } label: {
                    HStack {
                        Text("Clear Cache")
                        Spacer()
                        if media.isClearingCache { ProgressView() }
                    }
                    .foregroundStyle(.red)
                }
                .disabled(media.isClearingCache)
            } header: {
                Text("Cache")
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
        .localizedNavigationTitle("Settings")
        .task { await refreshCacheSize() }
        .task { await refreshHistoryCount() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshCacheSize() }
                Task { await refreshHistoryCount() }
            }
        }
        .background {
            // Scope the blue cancel tint to these two confirmations only.
            // Destructive actions retain their system red appearance.
            Color.clear
                .alert("Clear cached data?", isPresented: $showsClearCacheConfirmation) {
                    Button("Clear Cache", role: .destructive) { Task { await clearCache() } }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Cached images and gallery details will be removed. Browsing history will be kept.")
                }
                .alert("Sign out?", isPresented: $showsSignOutConfirmation) {
                    Button("Sign Out", role: .destructive) { session.signOut() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("You will need your API key to sign in again.")
                }
                .tint(Color(uiColor: .systemBlue))
        }
        .alert("Cache Cleared", isPresented: $showsCacheCleared) {
            Button("OK", role: .cancel) {}
        }
        .alert("Unable to clear cache", isPresented: $showsCacheError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let cacheError { Text(ErrorMessage.text(for: cacheError)) }
        }
    }

    private func clearCache() async {
        guard !media.isClearingCache else { return }
        do {
            try await media.clearImageCache()
            showsCacheCleared = true
        } catch {
            cacheError = error
            showsCacheError = true
        }
        await refreshCacheSize()
    }

    private func refreshHistoryCount() async {
        do {
            historyCount = try await BrowsingHistoryStore.shared.entries().count
        } catch {
            historyCount = nil
        }
    }

    private func refreshCacheSize() async {
        isLoadingCacheSize = true
        defer { isLoadingCacheSize = false }
        do {
            cacheSize = try await media.imageCacheSize()
        } catch {
            cacheSize = nil
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
