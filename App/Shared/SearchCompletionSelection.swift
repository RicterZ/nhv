import SwiftUI
import UIKit
import NHVCore

struct SearchCompletionRequest: Identifiable, Equatable {
    let id = UUID()
    let completion: SearchSyntax.Completion
}

struct SearchCompletionSelection: ViewModifier {
    let request: SearchCompletionRequest?

    func body(content: Content) -> some View {
        content
            .background(SearchCaretPlacement(request: request).frame(width: 0, height: 0))
    }
}

/// Apply a completion once to the current field. Persisting SwiftUI TextSelection
/// indices can trap when searchable clears or replaces its text on iOS 26.
private struct SearchCaretPlacement: UIViewControllerRepresentable {
    let request: SearchCompletionRequest?

    func makeUIViewController(context: Context) -> SelectionController { SelectionController() }

    func updateUIViewController(_ controller: SelectionController, context: Context) {
        controller.request = request
        DispatchQueue.main.async { [weak controller] in controller?.applySelection() }
    }

    final class SelectionController: UIViewController {
        var request: SearchCompletionRequest?
        private var appliedID: UUID?

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applySelection()
        }

        func applySelection() {
            guard let request, request.id != appliedID else { return }
            var ancestor = parent
            while let controller = ancestor {
                let search = controller.navigationItem.searchController
                    ?? controller.navigationController?.topViewController?.navigationItem.searchController
                if let field = search?.searchBar.searchTextField,
                   field.isFirstResponder, field.text == request.completion.text,
                   (0...request.completion.text.utf16.count).contains(request.completion.caretUTF16Offset),
                   let position = field.position(from: field.beginningOfDocument, offset: request.completion.caretUTF16Offset) {
                    field.selectedTextRange = field.textRange(from: position, to: position)
                    appliedID = request.id
                    return
                }
                ancestor = controller.parent
            }
        }
    }
}
