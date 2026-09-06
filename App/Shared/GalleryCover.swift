import SwiftUI

struct GalleryCover: View {
    let url: URL?
    var fillsStandardCoverWidth = false
    @Environment(MediaStore.self) private var media

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let url, let image = media.thumbnails.image(for: url) {
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
        .background(Color.white.opacity(0.04))
        .contextMenu {
            if let url, media.thumbnails.failures.contains(url) {
                Button("Try Again") { media.thumbnails.retry(url) }
            }
        }
        .onAppear {
            if let url { media.thumbnails.enqueue([url]) }
        }
    }
}
