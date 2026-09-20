import SwiftUI
import UIKit

/// Uses the same refresh action for touch gestures and the Mac toolbar.
struct GalleryRefresh: ViewModifier {
    let action: () async -> Void
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark
    @State private var isRefreshing = false
    @State private var refreshRequest: UUID?

    func body(content: Content) -> some View {
        content
            .refreshable { await refresh() }
            #if targetEnvironment(macCatalyst)
            .background {
                Button("Refresh") { refreshRequest = UUID() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(isRefreshing || refreshRequest != nil)
                    .frame(width: 0, height: 0)
                    .clipped()
                    .opacity(0)
                    .accessibilityHidden(true)
            }
            .toolbar {
                if #available(iOS 26.0, *) {
                    refreshToolbarItem.sharedBackgroundVisibility(.hidden)
                } else {
                    refreshToolbarItem
                }
            }
            .task(id: refreshRequest) {
                guard refreshRequest != nil else { return }
                await refresh()
                refreshRequest = nil
            }
            #endif
    }

    #if targetEnvironment(macCatalyst)
    private var refreshToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            RefreshIconButton(
                color: UIColor(theme.accentColor),
                isEnabled: !isRefreshing && refreshRequest == nil,
                label: String(localized: "Refresh"),
                action: { refreshRequest = UUID() }
            )
            .frame(width: 28, height: 28)
            .help(Text("Refresh"))

        }
    }
    #endif

    @MainActor
    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await action()
    }
}

#if targetEnvironment(macCatalyst)
/// A custom UIKit view avoids SwiftUI's native toolbar image conversion.
private struct RefreshIconButton: UIViewRepresentable {
    let color: UIColor
    let isEnabled: Bool
    let label: String
    let action: () -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.accessibilityIdentifier = "gallery.refresh"
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        let symbol = UIImage(systemName: "arrow.clockwise", withConfiguration: configuration)
        // Rasterize the colored symbol so no template metadata survives into
        // the native toolbar. Recreate it when the app theme changes.
        let icon = UIGraphicsImageRenderer(size: CGSize(width: 22, height: 22)).image { _ in
            guard let symbol else { return }
            let origin = CGPoint(x: (22 - symbol.size.width) / 2, y: (22 - symbol.size.height) / 2)
            symbol.withTintColor(color, renderingMode: .alwaysOriginal).draw(at: origin)
        }.withRenderingMode(.alwaysOriginal)
        button.setImage(icon, for: .normal)
        button.alpha = isEnabled ? 1 : 0.4
        button.isEnabled = isEnabled
        button.accessibilityLabel = label
        button.removeAction(identifiedBy: UIAction.Identifier("refresh"), for: .touchUpInside)
        button.addAction(UIAction(identifier: UIAction.Identifier("refresh")) { _ in action() }, for: .touchUpInside)
    }
}
#endif
