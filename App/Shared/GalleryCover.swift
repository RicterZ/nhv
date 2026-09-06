import SwiftUI

struct GalleryCover: View {
    let url: URL?
    @Environment(MediaStore.self) private var media

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let url, let image = media.thumbnails.image(for: url) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color.white)
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
