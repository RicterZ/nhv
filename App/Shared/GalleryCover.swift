import SwiftUI

struct GalleryCover: View {
    let url: URL?
    @Environment(MediaStore.self) private var media

    var body: some View {
        Group {
            if let url, let image = media.thumbnails.image(for: url) {
                Image(uiImage: image).resizable().scaledToFit()
            } else if let url, media.thumbnails.failures.contains(url) {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                    Text("Image unavailable")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
