import SwiftUI
import UIKit

struct LongPressCopy: ViewModifier {
    let value: String
    let actionName: LocalizedStringKey
    let onCopy: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onLongPressGesture { copy() }
            .accessibilityHint(Text("Long press to copy"))
            .accessibilityAction(named: Text(actionName)) { copy() }
    }

    private func copy() {
        UIPasteboard.general.string = value
        ClipboardGallery.ignoreCurrentContent()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onCopy()
    }
}
