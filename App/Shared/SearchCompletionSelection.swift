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
        if #available(iOS 26.0, *) {
            content.modifier(NativeSearchSelection(request: request))
        } else {
            content.background(LegacySearchSelection(request: request).frame(width: 0, height: 0))
        }
    }
}

@available(iOS 26.0, *)
private struct NativeSearchSelection: ViewModifier {
    let request: SearchCompletionRequest?
    @State private var selection: TextSelection?

    func body(content: Content) -> some View {
        content
            .searchSelection($selection)
            .onChange(of: request) { _, request in
                guard let completion = request?.completion else {
                    selection = nil
                    return
                }
                let index = String.Index(utf16Offset: completion.caretUTF16Offset, in: completion.text)
                selection = TextSelection(insertionPoint: index)
            }
    }
}

/// iOS 17–18 do not expose selection for SwiftUI's system search field.
/// Resolve only this screen's navigation search controller and keep its native behavior.
private struct LegacySearchSelection: UIViewControllerRepresentable {
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
