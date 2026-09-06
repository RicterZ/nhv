import SwiftUI

struct GalleryFilterChipStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .modifier(GalleryTagAppearance())
            .contentShape(Rectangle())
    }
}

/// Shared tag colors keep search chips and detail tags consistent.
struct GalleryTagAppearance: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    private var foreground: Color {
        colorScheme == .light ? Color(uiColor: .systemBlue)
            : Color(red: 237 / 255, green: 39 / 255, blue: 84 / 255)
    }

    private var background: Color {
        colorScheme == .light ? Color(uiColor: .systemBlue)
            : Color(red: 240 / 255, green: 82 / 255, blue: 117 / 255)
    }

    func body(content: Content) -> some View {
        content
            .foregroundStyle(foreground)
            .tint(foreground)
            .background(background.opacity(0.09), in: RoundedRectangle(cornerRadius: 6))
    }
}
