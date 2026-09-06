import SwiftUI

/// Keeps filters and results in one scroll view that drives the navigation bar.
struct GalleryScrollView<Header: View, Content: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                header()
                content()
            }
        }
    }
}
