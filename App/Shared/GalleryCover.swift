import SwiftUI
import UIKit

struct GalleryCover: View {
    let url: URL?
    var fillsStandardCoverWidth = false
    var retainsLoadedImage = false
    @Environment(MediaStore.self) private var media
    @State private var retainedImage: UIImage?
    @State private var retainedURL: URL?

    private var displayedImage: UIImage? {
        guard let url else { return nil }
        if retainsLoadedImage, retainedURL == url, let retainedImage { return retainedImage }
        return media.thumbnails.image(for: url)
    }

    private var imageToLoad: URL? {
        guard let url, displayedImage == nil,
              !media.thumbnails.isClearingCache,
              !media.thumbnails.failures.contains(url) else { return nil }
        return url
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image = displayedImage {
                    let ratio = image.size.width / max(1, image.size.height)
                    Group {
                        if fillsStandardCoverWidth && (480.0 / 720.0...520.0 / 680.0).contains(ratio) {
                            Image(uiImage: image)
                                .resizable()
                                .frame(width: geometry.size.width, height: geometry.size.width / ratio)
                        } else {
                            Image(uiImage: image).resizable().scaledToFit()
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                    .background(Color.white)
                    .clipped()
                } else if let url, media.thumbnails.failures.contains(url) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark")
                        Text("Image unavailable")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .background(Color.primary.opacity(0.04))
        .contextMenu {
            if let url, media.thumbnails.failures.contains(url) {
                Button("Try Again") { media.thumbnails.retry(url) }
            }
        }
        .onAppear {
            retainImageIfAvailable()
        }
        .task(id: imageToLoad) {
            // A cache miss can occur while the view stays mounted. Do not rely
            // on onAppear to restart loading after eviction or cache clearing.
            if let url = imageToLoad { media.thumbnails.enqueue([url]) }
        }
        .onChange(of: url) { _, _ in
            retainedImage = nil
            retainedURL = nil
            retainImageIfAvailable()
        }
        .onChange(of: media.thumbnails.revision) { _, _ in retainImageIfAvailable() }
        .onChange(of: media.thumbnails.cacheGeneration) { _, _ in
            retainedImage = nil
            retainedURL = nil
        }
    }

    private func retainImageIfAvailable() {
        guard retainsLoadedImage, let url, let image = media.thumbnails.image(for: url) else { return }
        retainedURL = url
        retainedImage = image
    }
}
