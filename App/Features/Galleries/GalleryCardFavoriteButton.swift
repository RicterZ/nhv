import SwiftUI
import NHVCore

struct GalleryCardFavoriteButton: View {
    let gallery: GallerySummary
    let api: NHentaiAPI
    let showsCount: Bool
    @Environment(FavoriteStore.self) private var favorites
    @State private var error: (any Error)?
    @State private var showsError = false

    var body: some View {
        Button {
            Task {
                do { try await favorites.toggle(id: gallery.id, fallbackCount: gallery.numFavorites, api: api) }
                catch { self.error = error; showsError = true }
            }
        } label: {
            HStack(spacing: 5) {
                if favorites.updating.contains(gallery.id) {
                    ProgressView().controlSize(.mini)
                        .tint(Color(red: 237 / 255, green: 39 / 255, blue: 84 / 255))
                } else {
                    Image(systemName: favorites.states[gallery.id]?.favorited == true ? "heart.fill" : "heart")
                        .foregroundStyle(Color(red: 237 / 255, green: 39 / 255, blue: 84 / 255))
                }
                if showsCount {
                    Text(favorites.states[gallery.id]?.count ?? gallery.numFavorites, format: .number)
                        .foregroundStyle(.black.opacity(0.8))
                        .monospacedDigit()
                }
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, showsCount ? 10 : 0)
            .frame(minWidth: 32, minHeight: 32)
            .background(.white.opacity(0.95), in: Capsule())
            .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
            .frame(minWidth: 44, minHeight: 44, alignment: .topTrailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(favorites.updating.contains(gallery.id))
        .accessibilityLabel(favorites.states[gallery.id]?.favorited == true ? Text("Unfavorite") : Text("Favorite"))
        .alert("Unable to update favorite", isPresented: $showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error { Text(ErrorMessage.text(for: error)) }
        }
    }
}
