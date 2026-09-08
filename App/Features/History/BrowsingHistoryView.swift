import SwiftUI
import NHVCore

struct BrowsingHistoryView: View {
    let api: NHentaiAPI
    @Environment(MediaStore.self) private var media
    @Environment(GalleryLanguageStore.self) private var languages
    @Environment(\.scenePhase) private var scenePhase
    @State private var entries: [BrowsingHistoryStore.Entry] = []
    @Environment(AppNavigation.self) private var navigation
    @State private var isLoading = true
    @State private var error: (any Error)?

    private var galleries: [GallerySummary] {
        entries.filter { $0.matches(titleQuery: navigation.historyQuery) }.map(\.gallery)
    }

    var body: some View {
        @Bindable var navigation = navigation
        GalleryScrollView(header: {
            HistorySearchField(text: $navigation.historyQuery)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }) {
            LazyVStack(spacing: 24) {
                if let error {
                    InlineErrorView(error: error)
                    Button("Try Again") { Task { await reload() } }
                }
                if !galleries.isEmpty {
                    GalleryGrid(galleries: galleries, api: api, showsFavoriteCount: false, recordsBrowsingHistory: false)
                } else if isLoading {
                    ProgressView("Loading galleries…").padding(24)
                } else if error == nil {
                    if entries.isEmpty {
                        ContentUnavailableView("No browsing history", systemImage: "clock",
                            description: Text("Galleries you open will appear here."))
                    } else {
                        ContentUnavailableView.search(text: navigation.historyQuery)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .localizedNavigationTitle("Browsing History")
        .scrollDismissesKeyboard(.interactively)
        .task { await reload() }
        .task {
            await media.prepare(api: api)
            await languages.prepare(api: api)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reload() } }
        }
        .refreshable { await reload() }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await BrowsingHistoryStore.shared.entries()
            try Task.checkCancellation()
            entries = result
            error = nil
        } catch is CancellationError {
            return
        } catch {
            self.error = error
        }
    }
}
