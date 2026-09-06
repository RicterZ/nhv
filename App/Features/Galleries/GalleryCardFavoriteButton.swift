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
            HStack(spacing: 4) {
                if favorites.updating.contains(gallery.id) {
                    ProgressView().controlSize(.mini).tint(.white)
                } else {
                    Image(systemName: favorites.states[gallery.id]?.favorited == true ? "heart.fill" : "heart")
                        .foregroundStyle(favorites.states[gallery.id]?.favorited == true
                            ? Color(red: 237 / 255, green: 39 / 255, blue: 84 / 255) : .white)
                }
                if showsCount {
                    Text(favorites.states[gallery.id]?.count ?? gallery.numFavorites, format: .number)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }
            .font(.caption2)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
            .frame(minWidth: 44, minHeight: 44, alignment: .bottomLeading)
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
