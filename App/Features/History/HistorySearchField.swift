import SwiftUI
import UIKit

/// Owned by the page instead of UINavigationItem's search controller, so the
/// field follows the page during interactive navigation transitions.
struct HistorySearchField: UIViewRepresentable {
    @Binding var text: String
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> UISearchTextField {
        let field = UISearchTextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .done
        field.clearButtonMode = .whileEditing
        field.adjustsFontForContentSizeCategory = true
        field.accessibilityIdentifier = "history.search"
        return field
    }

    func updateUIView(_ field: UISearchTextField, context: Context) {
        context.coordinator.text = $text
        if field.text != text { field.text = text }
        let placeholder = AppLocalization.string("Search history titles", locale: locale)
        field.placeholder = placeholder
        field.accessibilityLabel = placeholder
        field.font = .preferredFont(forTextStyle: .body)
        field.tintColor = UIColor((colorScheme == .dark ? AppTheme.dark : .light).accentColor)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISearchTextField, context: Context) -> CGSize? {
        CGSize(width: max(0, proposal.width ?? uiView.intrinsicContentSize.width),
               height: max(36, UIFontMetrics.default.scaledValue(for: 36)))
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) { self.text = text }

        @objc func textChanged(_ field: UISearchTextField) {
            text.wrappedValue = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}
