import SwiftUI
import UIKit

struct GalleryCover: View {
    let url: URL?
    var retainsLoadedImage = true
    var letterboxColor: Color = .white
    var stretchesSimilarAspectRatios = false
    @Environment(MediaStore.self) private var media
    @State private var retainedImage: UIImage?
    @State private var retainedURL: URL?
    @State private var retainedGeneration: Int?

    private var displayedImage: UIImage? {
        guard let url else { return nil }
        if retainsLoadedImage, retainedGeneration == media.thumbnails.cacheGeneration,
           retainedURL == url, let retainedImage { return retainedImage }
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
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(displayAspectRatio(for: image, in: geometry.size), contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                        .background(letterboxColor)
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
        retainedGeneration = media.thumbnails.cacheGeneration
        retainedURL = url
        retainedImage = image
    }

    private func displayAspectRatio(for image: UIImage, in size: CGSize) -> CGFloat? {
        guard stretchesSimilarAspectRatios,
              image.size.width > 0, image.size.height > 0,
              size.width > 0, size.height > 0 else { return nil }
        let imageRatio = image.size.width / image.size.height
        let containerRatio = size.width / size.height
        // Bound distortion in either direction; unusual formats keep their
        // original aspect ratio and remain fully visible without cropping.
        let stretch = max(imageRatio / containerRatio, containerRatio / imageRatio)
        return stretch <= 1.15 ? containerRatio : nil
    }
}
