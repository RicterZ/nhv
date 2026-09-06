import SwiftUI
import UIKit

/// Embeds the system search field beneath a custom page title.
struct GallerySearchField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isEditing: Bool
    let prompt: String.LocalizationValue
    let submit: () -> Void
    @Environment(\.locale) private var locale

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .search
        searchBar.delegate = context.coordinator
        return searchBar
    }

    func updateUIView(_ searchBar: UISearchBar, context: Context) {
        context.coordinator.parent = self
        if searchBar.text != text { searchBar.text = text }
        searchBar.placeholder = String(localized: prompt, locale: locale)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISearchBar, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? uiView.intrinsicContentSize.width, height: 52)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UISearchBarDelegate {
        var parent: GallerySearchField

        init(parent: GallerySearchField) { self.parent = parent }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            parent.isEditing = true
        }

        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            parent.isEditing = false
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            parent.submit()
            searchBar.resignFirstResponder()
        }
    }
}
