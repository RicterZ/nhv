import SwiftUI

struct GalleryFilterChipStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
    }
}
