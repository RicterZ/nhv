import SwiftUI

/// Uses the same refresh action for touch gestures and the Mac toolbar.
struct GalleryRefresh: ViewModifier {
    let action: () async -> Void
    @State private var isRefreshing = false
    @State private var refreshRequest: UUID?

    func body(content: Content) -> some View {
        content
            .refreshable { await refresh() }
            #if targetEnvironment(macCatalyst)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        refreshRequest = UUID()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .labelStyle(.iconOnly)
                    .keyboardShortcut("r", modifiers: .command)
                    .help(Text("Refresh"))
                    .disabled(isRefreshing || refreshRequest != nil)
                    .accessibilityIdentifier("gallery.refresh")
                }
            }
            .task(id: refreshRequest) {
                guard refreshRequest != nil else { return }
                await refresh()
                refreshRequest = nil
            }
            #endif
    }

    @MainActor
    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await action()
    }
}
