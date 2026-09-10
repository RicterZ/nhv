import SwiftUI
import NHVCore
import OSLog

struct GalleryDetailView: View {
    let api: NHentaiAPI
    let summary: GallerySummary?
    var recordsBrowsingHistory = true
    let id: Int
    private var galleryURL: URL { URL(string: "https://nhentai.net/g/\(id)/")! }
    private static let logger = Logger(subsystem: "local.nhv.reader", category: "BrowsingHistory")
    @Environment(MediaStore.self) private var media
    @Environment(FavoriteStore.self) private var favorites
    @Environment(GalleryLanguageStore.self) private var languages
    @Environment(\.locale) private var locale
    @State private var gallery: GalleryDetail?
    @State private var error: (any Error)?
    @State private var favoriteError: (any Error)?
    @State private var isLoading = false
    @State private var hasRecordedVisit = false
    @Environment(AppNavigation.self) private var navigation
    @State private var copyNotification: UUID?
    @State private var openedAt = Date()
    @State private var relatedRefreshID = 0
    @AppStorage(ContentDisplayPreference.relatedKey) private var showsRelatedGalleries = true

    init(api: NHentaiAPI, summary: GallerySummary, recordsBrowsingHistory: Bool = true) {
        self.api = api
        self.summary = summary
        self.id = summary.id
        self.recordsBrowsingHistory = recordsBrowsingHistory
    }

    init(api: NHentaiAPI, id: Int, recordsBrowsingHistory: Bool = true) {
        self.recordsBrowsingHistory = recordsBrowsingHistory
        self.api = api
        self.id = id
        self.summary = nil
    }

    var body: some View {
        GeometryReader { geometry in
            let twoColumns = UIDevice.current.userInterfaceIdiom == .pad
                && geometry.size.width > geometry.size.height
                && geometry.size.width >= 760
            ScrollView {
                if let gallery {
                    VStack(alignment: .leading, spacing: 24) {
                        if let mediaError = media.error {
                            InlineErrorView(error: mediaError)
                            Button("Try Again") { Task { await load() } }
                        }
                        GalleryDetailHeader(twoColumns: twoColumns, availableWidth: geometry.size.width) {
                            GalleryCover(url: media.thumbnail(gallery.cover.path, galleryID: id, kind: .cover), retainsLoadedImage: true, letterboxColor: Color(uiColor: .systemBackground))
                                .aspectRatio(CGFloat(gallery.cover.width) / CGFloat(max(1, gallery.cover.height)), contentMode: .fit)
                                .frame(maxWidth: .infinity)
                        } information: {
                            galleryInformation(gallery)
                        }

                        if !gallery.pages.isEmpty {
                            Text("Pages").font(.headline)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                                ForEach(Array(gallery.pages.enumerated()), id: \.element.id) { index, page in
                                    Button {
                                        navigation.reader = AppNavigation.ReaderState(galleryID: id, pages: gallery.pages, initialIndex: index)
                                    } label: {
                                        GalleryCover(url: media.thumbnail(page.thumbnail, galleryID: id, kind: .pageThumbnail(page.number)), letterboxColor: Color(uiColor: .systemBackground))
                                            .aspectRatio(0.7, contentMode: .fit)
                                            .overlay(alignment: .bottomTrailing) {
                                                Text(page.number, format: .number)
                                                    .foregroundStyle(.white)
                                                    .font(.caption2.monospacedDigit())
                                                    .padding(4)
                                                    .background(.black.opacity(0.8))
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text("Open page \(index + 1)"))
                                }
                            }
                        }

                        if showsRelatedGalleries {
                            RelatedGalleriesSection(api: api, galleryID: id, refreshID: relatedRefreshID)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: twoColumns ? 1100 : 760)
                    .frame(maxWidth: .infinity)
                } else if let error {
                    VStack(spacing: 16) {
                        InlineErrorView(error: error)
                        Button("Try Again") { Task { await load() } }
                    }.padding(24)
                } else {
                    ProgressView("Loading gallery…").padding(32)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(String(id))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(verbatim: String(id))
                    .font(.headline)
                    .frame(minHeight: 44)
                    .modifier(LongPressCopy(value: galleryURL.absoluteString, actionName: "Copy link", onCopy: showCopied))
            }
            if #available(iOS 26.0, *) {
                shareToolbarItem.sharedBackgroundVisibility(.hidden)
            } else {
                shareToolbarItem
            }
        }
        .refreshable {
            await load(refresh: true)
            if showsRelatedGalleries { relatedRefreshID += 1 }
        }
        .overlay(alignment: .top) {
            if copyNotification != nil {
                Label("Copied", systemImage: "checkmark")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                    .padding(.top, 12)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: copyNotification != nil)
        .task(id: copyNotification) {
            guard let notification = copyNotification else { return }
            do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
            if copyNotification == notification { copyNotification = nil }
        }
        .onDisappear { copyNotification = nil }
        .onAppear {
            guard let summary, recordsBrowsingHistory, !hasRecordedVisit else { return }
            hasRecordedVisit = true
            let visitedAt = Date()
            // Independent of the detail request and its cancellation: even a
            // failed load or a quick Back action should preserve this visit.
            Task {
                do {
                    try await BrowsingHistoryStore.shared.record(summary, visitedAt: visitedAt)
                } catch {
                    Self.logger.error("Unable to save browsing history: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        .task { if gallery == nil { await load() } }

    }

    private func showCopied() {
        copyNotification = UUID()
    }

    private var shareToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ShareLink(item: galleryURL) {
                Image(systemName: "square.and.arrow.up")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Share"))
        }
    }

    private func load(refresh: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        let favoriteVersion = favorites.version(for: id)
        do {
            let result = try await GalleryDetailCache.shared.gallery(id: id, api: api, refresh: refresh)
            try Task.checkCancellation()
            favorites.remember(id: id, favorited: result.isFavorited, count: result.numFavorites,
                expectedVersion: favoriteVersion)
            languages.remember(result.tags)
            gallery = result
            if summary == nil, recordsBrowsingHistory, !hasRecordedVisit {
                hasRecordedVisit = true
                let visitedAt = openedAt
                Task {
                    do { try await BrowsingHistoryStore.shared.record(GallerySummary(detail: result), visitedAt: visitedAt) }
                    catch { Self.logger.error("Unable to save browsing history: \(error.localizedDescription, privacy: .public)") }
                }
            }
            await media.prepare(api: api)
            let cover = media.thumbnail(result.cover.path, galleryID: id, kind: .cover)
            let pages = result.pages.prefix(6).compactMap {
                media.thumbnail($0.thumbnail, galleryID: id, kind: .pageThumbnail($0.number))
            }
            media.thumbnails.enqueue([cover].compactMap { $0 } + pages)
            // Account-specific state is refreshed separately without blocking
            // cached content or turning an offline visit into a detail error.
            if result.isFavorited == nil {
                await favorites.refresh(id: id, api: api)
            }
        } catch is CancellationError { return }
        catch { self.error = error }
    }

    private func toggleFavorite() async {
        guard let state = favorites.states[id] else { return }
        favoriteError = nil
        do { try await favorites.set(id: id, favorited: !state.favorited, api: api) }
        catch { favoriteError = error }
    }

    private func galleryInformation(_ gallery: GalleryDetail) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                GalleryTitleLabel(title: gallery.title.pretty, tagIDs: gallery.tags.map(\.id))
                    .font(.title2.bold())
                    .modifier(LongPressCopy(value: gallery.title.pretty, actionName: "Copy title", onCopy: showCopied))
                if let japanese = gallery.title.japanese, !japanese.isEmpty {
                    Text(verbatim: japanese)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .modifier(LongPressCopy(value: japanese, actionName: "Copy subtitle", onCopy: showCopied))
                }
            }

            HStack {
                Label("\(gallery.numPages) pages", systemImage: "book")
                Spacer()
                Button {
                    Task { await toggleFavorite() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: favorites.states[id]?.favorited == true ? "heart.fill" : "heart")
                            .foregroundStyle(favorites.states[id]?.favorited == true
                                ? Color(red: 237 / 255, green: 39 / 255, blue: 84 / 255)
                                : Color.secondary)
                        Text(favorites.states[id]?.count ?? gallery.numFavorites, format: .number)
                            .monospacedDigit()
                    }
                    .opacity(favorites.updating.contains(id) ? 0.3 : 1)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .overlay {
                        if favorites.updating.contains(id) { ProgressView() }
                    }
                }
                .buttonStyle(.plain)
                .disabled(favorites.updating.contains(id) || favorites.states[id] == nil)
                .accessibilityLabel(favorites.states[id]?.favorited == true ? Text("Unfavorite") : Text("Favorite"))
                .accessibilityValue((favorites.states[id]?.count ?? gallery.numFavorites).formatted(.number.locale(locale)))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let favoriteError { InlineErrorView(error: favoriteError) }
            if let error { InlineErrorView(error: error) }

            LabeledContent("Uploaded") {
                Text(Date(timeIntervalSince1970: Double(gallery.uploadDate)), format: .dateTime.year().month().day())
            }
            .font(.subheadline)
            if !gallery.scanlator.isEmpty {
                LabeledContent("Scanlator", value: gallery.scanlator)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(Set(gallery.tags.map(\.type))).sorted(), id: \.self) { type in
                    FlowLayout {
                        tagTypeTitle(type)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 4)
                        ForEach(gallery.tags.filter { $0.type == type }) { tag in
                            // Keep this detail and its originating search on the
                            // stack; the destination owns its own query and sort.
                            Button {
                                navigation.push(.init(.search(tag.searchQuery)))
                            } label: {
                                HStack(spacing: 4) {
                                    Text(verbatim: tag.name)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(tag.count, format: .number.notation(.compactName))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .fixedSize()
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .modifier(GalleryTagAppearance())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func tagTypeTitle(_ type: String) -> Text {
        switch type {
        case "artist": Text("Artists")
        case "group": Text("Groups")
        case "parody": Text("Parodies")
        case "character": Text("Characters")
        case "language": Text("Languages")
        case "category": Text("Categories")
        case "tag": Text("Tags")
        default: Text(verbatim: type)
        }
    }
}
