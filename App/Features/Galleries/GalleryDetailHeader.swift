import SwiftUI

/// Keep the same content identity when the iPad window changes shape.
struct GalleryDetailHeader<Cover: View, Information: View>: View {
    let twoColumns: Bool
    let availableWidth: CGFloat
    @ViewBuilder var cover: () -> Cover
    @ViewBuilder var information: () -> Information

    var body: some View {
        let layout = twoColumns
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 32))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 24))
        layout {
            cover()
                .frame(width: twoColumns ? min(380, (min(availableWidth, 1100) - 64) * 0.4) : nil)
            information()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
