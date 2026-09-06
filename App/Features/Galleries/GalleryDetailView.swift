import SwiftUI
import NHVCore

struct GalleryDetailView: View {
    let api: NHentaiAPI
    let id: Int
    @Environment(MediaStore.self) private var media
    @Environment(FavoriteStore.self) private var favorites
    @Environment(GalleryLanguageStore.self) private var languages
    @State private var gallery: GalleryDetail?
    @State private var error: (any Error)?
    @State private var favoriteError: (any Error)?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            if let gallery {
                VStack(alignment: .leading, spacing: 24) {
                    if let mediaError = media.error {
                        InlineErrorView(error: mediaError)
                        Button("Try Again") { Task { await load() } }
                    }
                    GalleryCover(url: media.thumbnail(gallery.cover.path))
                        .aspectRatio(CGFloat(gallery.cover.width) / CGFloat(max(1, gallery.cover.height)), contentMode: .fit)
                        .frame(maxWidth: 280)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        GalleryTitleLabel(title: gallery.title.pretty, tagIDs: gallery.tags.map(\.id))
                            .font(.title2.bold())
                            .textSelection(.enabled)
                        if let japanese = gallery.title.japanese, !japanese.isEmpty {
                            Text(verbatim: japanese)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }

                    HStack {
                        Label("\(gallery.numPages) pages", systemImage: "book")
                        Spacer()
                        Label((favorites.states[id]?.count ?? gallery.numFavorites).formatted(), systemImage: "heart")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Button {
                        Task { await toggleFavorite() }
                    } label: {
                        if favorites.updating.contains(id) {
                            ProgressView()
                        } else if favorites.states[id]?.favorited == true {
                            Label("Unfavorite", systemImage: "heart.fill")
                        } else {
                            Label("Favorite", systemImage: "heart")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(favorites.updating.contains(id) || favorites.states[id] == nil)

                    if let favoriteError { InlineErrorView(error: favoriteError) }
                    if let error { InlineErrorView(error: error) }

                    LabeledContent("Uploaded") {
                        Text(Date(timeIntervalSince1970: Double(gallery.uploadDate)), format: .dateTime.year().month().day())
                    }
                    .font(.subheadline)
                    if !gallery.scanlator.isEmpty {
                        LabeledContent("Scanlator", value: gallery.scanlator)
                    }

                    ForEach(Array(Set(gallery.tags.map(\.type))).sorted(), id: \.self) { type in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tagTypeTitle(type)).font(.subheadline.weight(.semibold))
                            FlowLayout {
                                ForEach(gallery.tags.filter { $0.type == type }) { tag in
                                    NavigationLink {
                                        TagGalleriesView(api: api, tag: tag)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(verbatim: tag.name)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text(tag.count.formatted(.number.notation(.compactName)))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .fixedSize()
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                        }
                    }

                    if !gallery.pages.isEmpty {
                        Text("Pages").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                            ForEach(gallery.pages) { page in
                                GalleryCover(url: media.thumbnail(page.thumbnail))
                                    .aspectRatio(0.7, contentMode: .fit)
                                    .overlay(alignment: .bottomTrailing) {
                                        Text(page.number.formatted())
                                            .font(.caption2.monospacedDigit())
                                            .padding(4)
                                            .background(.black.opacity(0.8))
                                    }
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: 760)
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
        .background(Color.black)
        .navigationTitle(String(id))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { if gallery == nil { await load() } }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            await media.prepare(api: api)
            let result = try await api.gallery(id: id)
            try Task.checkCancellation()
            media.thumbnails.enqueue(([result.cover.path] + result.pages.map(\.thumbnail)).compactMap { media.thumbnail($0) })
            favorites.remember(id: id, favorited: result.isFavorited, count: result.numFavorites)
            languages.remember(result.tags)
            gallery = result
            if result.isFavorited == nil {
                let state = try await api.favorite(id: id)
                favorites.remember(id: id, favorited: state.favorited, count: state.numFavorites)
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

    private func tagTypeTitle(_ type: String) -> String {
        switch type {
        case "artist": String(localized: "Artists")
        case "group": String(localized: "Groups")
        case "parody": String(localized: "Parodies")
        case "character": String(localized: "Characters")
        case "language": String(localized: "Languages")
        case "category": String(localized: "Categories")
        case "tag": String(localized: "Tags")
        default: type
        }
    }
}
