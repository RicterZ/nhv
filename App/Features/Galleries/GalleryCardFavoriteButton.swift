import SwiftUI
import NHVCore

struct GalleryCardFavoriteButton: View {
    let gallery: GallerySummary
    let api: NHentaiAPI
    let showsCount: Bool
    var prefersResultCount = false
    @Environment(FavoriteStore.self) private var favorites
    @Environment(\.colorScheme) private var colorScheme
    @State private var error: (any Error)?
    @State private var showsError = false

    private var displayedCount: Int {
        if prefersResultCount { return gallery.numFavorites }
        return favorites.states[gallery.id]?.count ?? gallery.numFavorites
    }

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
                    Text(displayedCount, format: .number)
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                        .monospacedDigit()
                }
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, showsCount ? 8 : 0)
            .frame(minWidth: 28, minHeight: 28)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.16 : 0.4), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
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
