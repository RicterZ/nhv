import SwiftUI
import NHVCore

/// Shared large-title row keeps the filter aligned with the title, not the navigation toolbar.
struct GalleryBrowsePage<Content: View>: View {
    let title: Text
    @Binding var sort: GallerySort
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                title
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                GallerySortPicker(selection: $sort)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}
