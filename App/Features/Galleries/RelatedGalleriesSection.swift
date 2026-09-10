import NHVCore
import SwiftUI

struct RelatedGalleriesSection: View {
    let api: NHentaiAPI
    let galleryID: Int
    let refreshID: Int
    @Environment(MediaStore.self) private var media
    @State private var galleries: [GallerySummary] = []
    @State private var isLoading = true
    @State private var error: (any Error)?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                separator(fadesTowardLeadingEdge: true)
                Circle()
                    .fill(Color.primary.opacity(0.195))
                    .frame(width: 3, height: 3)
                separator(fadesTowardLeadingEdge: false)
            }
            .padding(.top, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Related"))

            if let error {
                VStack(spacing: 12) {
                    InlineErrorView(error: error)
                    Button("Try Again") { Task { await load() } }
                }
                .frame(maxWidth: .infinity)
            }

            if !galleries.isEmpty {
                GalleryGrid(galleries: galleries, api: api, showsFavoriteCount: true,
                    respectsNSFWSetting: true, columnCount: 3, usesCompactCards: true)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            }
        }
        .task(id: refreshID) { await load() }
    }

    private func separator(fadesTowardLeadingEdge: Bool) -> some View {
        Rectangle()
            .fill(LinearGradient(
                colors: fadesTowardLeadingEdge
                    ? [.clear, Color.primary.opacity(0.105)]
                    : [Color.primary.opacity(0.105), .clear],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(maxWidth: .infinity)
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private func load() async {
        guard !isLoading || galleries.isEmpty else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let result = try await api.relatedGalleries(id: galleryID)
            try Task.checkCancellation()
            await media.prepare(api: api)
            try Task.checkCancellation()
            let urls = result.compactMap { media.thumbnail($0.thumbnail, galleryID: $0.id) }
            media.thumbnails.enqueue(urls)
            galleries = result
        } catch is CancellationError {
            return
        } catch {
            self.error = error
        }
    }
}
