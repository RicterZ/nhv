import SwiftUI

struct GalleryFilterChipStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .light {
            chip(content)
                .foregroundStyle(Color(uiColor: .systemBlue))
                .tint(Color(uiColor: .systemBlue))
        } else {
            chip(content)
        }
    }

    private func chip(_ content: Content) -> some View {
        content
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
    }
}
